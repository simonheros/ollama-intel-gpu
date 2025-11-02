# -----------------------------------------------------------------------------
# Ollama (IPEX-LLM) + PyTorch-XPU (IPEX) + OpenVINO on Intel oneAPI basekit
# Pinned base: intel/oneapi-basekit:2025.3.0-0-devel-ubuntu24.04
# Optimized for: dual Intel Arc A770 (16GB each) + AMD 5950X (16 physical cores)
# -----------------------------------------------------------------------------
FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG IPEXLLM_VERSION=2.2.0
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=llama-cpp-ipex-llm-${IPEXLLM_VERSION}-ubuntu-core.tgz

ENV TZ=UTC \
    PATH="/opt/intel/oneapi/compiler/latest/linux/bin:${PATH}" \
    LD_LIBRARY_PATH="/opt/intel/oneapi/compiler/latest/linux/lib:${LD_LIBRARY_PATH}" \
    # GPU-first (oneAPI / Level Zero)
    ONEAPI_DEVICE_SELECTOR=level_zero:gpu \
    SYCL_DEVICE_FILTER=level_zero:gpu \
    SYCL_PI_LEVEL_ZERO_USE_MULTI_DEVICE_CONTEXT=1 \
    SYCL_QUEUE_THREAD_POOL_SIZE=16 \
    LIBZE_INTEL_GPU_MAX_HEAP_SIZE_MB=16000 \
    OPENVINO_DEVICE=GPU \
    OPENVINO_LOG_LEVEL=INFO \
    TORCH_DEVICE=xpu \
    OMP_NUM_THREADS=16 \
    MKL_NUM_THREADS=16 \
    KMP_AFFINITY=granularity=fine,compact,1,0 \
    GOMP_CPU_AFFINITY=0-15

# minimal apt packages
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
      wget curl ca-certificates python3 python3-pip python3-venv \
      git pciutils clinfo lsb-release build-essential procps iproute2 jq curl \
      && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Install PyTorch + IPEX (XPU) using Intel wheel index (auto-detect Python tag).
# This tries Intel's index first, then falls back to a safe pip approach if needed.
# ----------------------------
RUN set -eux; \
    python3 -m pip install --upgrade pip setuptools wheel; \
    PY_TAG=$(python3 - <<'PY' \
import sys
print(f"cp{sys.version_info[0]}{sys.version_info[1]}")
PY
); \
    echo "Detected Python ABI tag: ${PY_TAG}"; \
    # Try Intel's PyTorch XPU wheel index (preferred). If it fails, attempt fallback.
    echo "Attempting to install PyTorch + IPEX from Intel XPU wheel index..."; \
    if python3 -m pip install --no-cache-dir --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ \
        "torch==2.3.1" "torchvision==0.18.1" "intel-extension-for-pytorch==2.3.110+xpu"; then \
        echo "✅ Installed torch + ipex from Intel XPU index"; \
    else \
        echo "⚠️ Intel XPU index install failed — trying fallback pip installs"; \
        # Fallback: install torch first (may install CPU wheel), then try ipex (may fail if no +xpu wheel available) \
        python3 -m pip install --no-cache-dir "torch==2.3.1" "torchvision==0.18.1" || (echo "ERROR: torch install failed"; exit 1); \
        python3 -m pip install --no-cache-dir "intel-extension-for-pytorch==2.3.110+xpu" || echo "⚠️ ipex +xpu wheel not found on fallback — you may need to use Intel wheel index or adjust versions"; \
    fi

# ----------------------------
# Install OpenVINO runtime + dev tools (pinned)
# ----------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir "openvino==2024.4.0" "openvino-dev==2024.4.0" "openvino-tokenizers==2024.4.0" || true

# ----------------------------
# Install IPEX-LLM (Ollama portable)
# ----------------------------
RUN set -eux; \
    cd / && \
    echo "Downloading IPEX-LLM portable: ${IPEXLLM_PORTABLE_ZIP_FILENAME}"; \
    apt-get update -y && apt-get install -y --no-install-recommends ca-certificates wget tar && rm -rf /var/lib/apt/lists/*; \
    if wget -q https://github.com/intel/ipex-llm/releases/download/v${IPEXLLM_VERSION}/${IPEXLLM_PORTABLE_ZIP_FILENAME} -O /tmp/${IPEXLLM_PORTABLE_ZIP_FILENAME}; then \
        tar -xzf /tmp/${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C /; \
        rm -f /tmp/${IPEXLLM_PORTABLE_ZIP_FILENAME}; \
        if [ -f /ollama ]; then chmod +x /ollama || true; fi; \
    else \
        echo "ERROR: Unable to download IPEX-LLM tarball ${IPEXLLM_PORTABLE_ZIP_FILENAME}"; exit 1; \
    fi

# ----------------------------
# Supervisor, verification and helper scripts
# ----------------------------
# verify-gpu.sh
COPY <<'EOF' /usr/local/bin/verify-gpu.sh
#!/usr/bin/env bash
set -euo pipefail
echo "=== verify-gpu.sh: SYCL/LevelZero/OpenVINO/PyTorch-XPU check ==="
echo
echo "-- sycl-ls --"
if command -v sycl-ls >/dev/null 2>&1; then sycl-ls || true; else echo "sycl-ls not found"; fi
echo
echo "-- clinfo (OpenCL) --"
if command -v clinfo >/dev/null 2>&1; then clinfo | grep -E "Platform|Device" || true; else echo "clinfo not found"; fi
echo
echo "-- Level Zero libs --"
ldconfig -p | grep -E "libze|level_zero" || echo "Level Zero libs not found"
echo
echo "-- PyTorch / IPEX --"
python3 - <<'PY'
import importlib
try:
    import torch
    print("torch", torch.__version__)
    try:
        ipex = importlib.import_module("intel_extension_for_pytorch")
        print("ipex", ipex.__version__)
    except Exception as e:
        print("ipex not available:", e)
    try:
        print("torch.xpu.is_available():", torch.xpu.is_available())
    except Exception as e:
        print("xpu check failed:", e)
except Exception as e:
    print("torch import failed:", e)
PY
echo
echo "-- OpenVINO --"
python3 - <<'PY'
try:
    from openvino.runtime import Core
    core = Core()
    print("OpenVINO devices:", core.available_devices)
except Exception as e:
    print("OpenVINO check failed:", e)
PY
echo
echo "-- env --"
env | grep -E "ONEAPI|SYCL|OPENVINO|LIBZE|TORCH"
echo "=== verify complete ==="
EOF
RUN chmod +x /usr/local/bin/verify-gpu.sh

# gpu_supervisor.py (concise)
COPY <<'EOF' /usr/local/bin/gpu_supervisor.py
#!/usr/bin/env python3
import os, subprocess, shutil, sys, time
def detect_gpus():
    if shutil.which("sycl-ls"):
        try:
            out = subprocess.run(["sycl-ls"], capture_output=True, text=True).stdout
            return len([l for l in out.splitlines() if "level_zero:gpu" in l])
        except Exception:
            pass
    try:
        from openvino.runtime import Core
        core = Core()
        return sum(1 for d in core.available_devices if "GPU" in d)
    except Exception:
        pass
    try:
        nodes = [n for n in os.listdir("/dev/dri") if n.startswith("render")]
        return len(nodes)
    except Exception:
        return 0

def spawn(cmd, env, cores):
    if cores:
        core_list = ",".join(str(c) for c in cores)
        cmd = ["taskset", "-c", core_list] + cmd
    return subprocess.Popen(cmd, env=env)

def main():
    workers_per_gpu = int(os.environ.get("WORKERS_PER_GPU", "1"))
    start_port = int(os.environ.get("START_PORT", "11434"))
    physical_cores = int(os.environ.get("PHYSICAL_CORES", "16"))
    cores_per_worker = int(os.environ.get("CORES_PER_WORKER", "4"))
    cmd_template = os.environ.get("OLLAMA_CMD_TEMPLATE", "/ollama serve --port {port}")
    ngpu = detect_gpus()
    if ngpu <= 0:
        print("No GPUs detected; exiting supervisor.")
        sys.exit(1)
    procs=[]
    port = start_port
    widx = 0
    for g in range(ngpu):
        for w in range(workers_per_gpu):
            env = os.environ.copy()
            env["SYCL_DEVICE_FILTER"]=f"level_zero:gpu:{g}"
            start = (widx * cores_per_worker) % physical_cores
            cores = [(start + i) % physical_cores for i in range(cores_per_worker)]
            cmd = cmd_template.format(port=port, gpu=g, worker=widx).split()
            print(f"Starting worker {widx} gpu={g} port={port} cores={cores} cmd={' '.join(cmd)}")
            p = spawn(cmd, env, cores)
            procs.append(p)
            port += 1; widx += 1
            time.sleep(0.4)
    try:
        while True:
            alive=[p for p in procs if p.poll() is None]
            if not alive:
                print("All workers exited"); break
            time.sleep(5)
    except KeyboardInterrupt:
        print("Terminating workers")
        for p in procs:
            p.terminate()
        time.sleep(2)
        for p in procs:
            if p.poll() is None:
                p.kill()

if __name__=='__main__':
    main()
EOF
RUN chmod +x /usr/local/bin/gpu_supervisor.py

# start-supervised-ollama.sh
COPY <<'EOF' /usr/local/bin/start-supervised-ollama.sh
#!/usr/bin/env bash
set -euo pipefail
exec /usr/local/bin/gpu_supervisor.py
EOF
RUN chmod +x /usr/local/bin/start-supervised-ollama.sh

# hybrid runtime selector (simple)
COPY <<'EOF' /usr/local/bin/hybrid_runtime.py
#!/usr/bin/env python3
import os
print("=== hybrid_runtime: choosing backend ===")
use_openvino=False
try:
    from openvino.runtime import Core
    devs = Core().available_devices
    use_openvino = any("GPU" in d for d in devs)
    print("OpenVINO devices:", devs)
except Exception as e:
    print("OpenVINO check error:", e)
use_ipex=False
try:
    import torch
    use_ipex = torch.xpu.is_available()
    print("torch.xpu.is_available():", use_ipex)
except Exception as e:
    print("torch xpu check error:", e)
if use_openvino:
    print("Selecting OpenVINO as primary inference backend")
    os.environ["OPENVINO_DEVICE"]="GPU"
    os.environ.pop("IPEX_DISABLE", None)
elif use_ipex:
    print("Selecting IPEX (PyTorch XPU) backend")
    os.environ["OPENVINO_DEVICE"]="CPU"
else:
    print("No GPU backend detected; CPU-only mode")
EOF
RUN chmod +x /usr/local/bin/hybrid_runtime.py

# Entrypoint: verify -> hybrid runtime -> supervisor or run CMD
COPY <<'EOF' /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -gt 0 ]; then
  exec "$@"
fi
echo "=== container startup: hybrid verification ==="
/usr/local/bin/verify-gpu.sh || true
/usr/bin/python3 /usr/local/bin/hybrid_runtime.py || true
echo "=== starting supervised Ollama workers ==="
exec /usr/local/bin/start-supervised-ollama.sh
EOF
RUN chmod +x /usr/local/bin/entrypoint.sh

# Labels + healthcheck
LABEL org.opencontainers.image.title="ollama-intel-hybrid-ovms" \
      org.opencontainers.image.version="${IPEXLLM_VERSION}" \
      org.opencontainers.image.description="Ollama (IPEX-LLM) + PyTorch-XPU + OpenVINO hybrid, oneAPI GPU-first (dual A770)"

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://127.0.0.1:11434/ || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
