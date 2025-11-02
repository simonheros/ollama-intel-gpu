# -----------------------------------------------------------------------------
# Ollama (IPEX-LLM) + PyTorch XPU (IPEX) + OpenVINO (GPU) - stable tags
# - Base: intel/oneapi-basekit pinned to a published tag for Ubuntu 24.04
# - IPEX-LLM: v2.2.0 (Ollama portable)
# - PyTorch / IPEX: target PyTorch 2.6 + IPEX 2.6.x+xpu (Intel provides +xpu wheels)
# - OpenVINO: 2024.5 runtime; OVMS as a sidecar (see docker-compose)
# -----------------------------------------------------------------------------
FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG IPEXLLM_VERSION=2.2.0
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=ollama-cpp-ipex-llm-${IPEXLLM_VERSION}-ubuntu-core.tgz

ENV TZ=UTC \
    # GPU-first: prefer oneAPI / Level Zero
    ONEAPI_DEVICE_SELECTOR=level_zero:gpu \
    SYCL_DEVICE_FILTER=level_zero:gpu \
    SYCL_PI_LEVEL_ZERO_USE_MULTI_DEVICE_CONTEXT=1 \
    SYCL_QUEUE_THREAD_POOL_SIZE=16 \
    LIBZE_INTEL_GPU_MAX_HEAP_SIZE_MB=16000 \
    OPENVINO_DEVICE=GPU \
    OPENVINO_LOG_LEVEL=INFO \
    TORCH_DEVICE=xpu \
    # CPU tuning for 5950X (16 physical cores); adjust if you reserve host cores
    OMP_NUM_THREADS=16 \
    MKL_NUM_THREADS=16 \
    KMP_AFFINITY=granularity=fine,compact,1,0 \
    GOMP_CPU_AFFINITY=0-15

# Minimal system packages
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      wget curl ca-certificates python3 python3-pip python3-venv \
      git pciutils clinfo lsb-release build-essential procps iproute2 jq && \
    rm -rf /var/lib/apt/lists/*

# Make sure pip is recent
RUN set -eux; python3 -m pip install --upgrade pip setuptools wheel

# -------------------------
# Install PyTorch + Intel Extension for PyTorch (IPEX XPU)
# Strategy:
# 1) Try Intel +xpu wheel index (recommended).
# 2) If that fails, try fallback installs and emit clear warnings.
# Note: Intel publishes matching +xpu wheels for PyTorch 2.6 and IPEX 2.6.x.
# -------------------------
RUN set -eux; \
    echo "==> Attempting to install PyTorch 2.6 + IPEX 2.6.x (+xpu wheels) from Intel index"; \
    if python3 -m pip install --no-cache-dir \
        --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ \
        torch==2.6.0 torchvision==0.19.0 intel-extension-for-pytorch==2.6.10+xpu; then \
        echo "✅ Installed torch 2.6.0 + ipex 2.6.10+xpu from Intel index"; \
    else \
        echo "⚠️ Intel XPU index install failed; trying fallback (may be CPU-only or fail)"; \
        python3 -m pip install --no-cache-dir torch==2.6.0 torchvision==0.19.0 || (echo "ERROR: torch install failed"; exit 1); \
        # Attempt to install ipex XPU - may fail if wheel not found; warn but continue
        python3 -m pip install --no-cache-dir intel-extension-for-pytorch==2.6.10+xpu || echo "⚠️ intel-extension-for-pytorch +xpu wheel not found on fallback"; \
    fi

# -------------------------
# Install OpenVINO runtime & dev (pinned to 2024.5)
# -------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir openvino==2024.5.0 openvino-dev==2024.5.0 || true

# -------------------------
# Install IPEX-LLM (Ollama portable)
# -------------------------
RUN set -eux; \
    cd /; \
    echo "==> Downloading IPEX-LLM portable ${IPEXLLM_PORTABLE_ZIP_FILENAME}"; \
    if wget -q https://github.com/intel/ipex-llm/releases/download/v${IPEXLLM_VERSION}/${IPEXLLM_PORTABLE_ZIP_FILENAME} -O /tmp/${IPEXLLM_PORTABLE_ZIP_FILENAME}; then \
        tar -xzf /tmp/${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C /; \
        rm -f /tmp/${IPEXLLM_PORTABLE_ZIP_FILENAME}; \
        chmod +x /ollama || true; \
    else \
        echo "ERROR: Failed to download IPEX-LLM artifact ${IPEXLLM_PORTABLE_ZIP_FILENAME}"; exit 1; \
    fi

# -------------------------
# Verification script (simple)
# -------------------------
COPY <<'PY' /usr/local/bin/verify-gpu.py
#!/usr/bin/env python3
import subprocess, os, sys
print("=== verify-gpu.py ===")
def run(cmd):
    try:
        p=subprocess.run(cmd,capture_output=True,text=True,check=False)
        print("$ "+" ".join(cmd))
        print(p.stdout or p.stderr)
    except Exception as e:
        print("Error:",e)
print("sycl-ls:")
run(["sycl-ls"])
print("clinfo:")
run(["clinfo"])
print("ldconfig -p | grep libze")
run(["/sbin/ldconfig","-p"])
print("PyTorch/IPEX check:")
run(["python3","-c","import torch;print('torch',torch.__version__);import importlib;print('ipex', 'ok' if importlib.util.find_spec('intel_extension_for_pytorch') else 'missing')"])
print("OpenVINO devices:")
run(["python3","-c","from openvino.runtime import Core; print(Core().available_devices)"])
PY
RUN chmod +x /usr/local/bin/verify-gpu.py

# Entrypoint: flexible — if args passed, run them; else verify and start /ollama serve
COPY <<'SH' /usr/local/bin/entrypoint.sh
#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -gt 0 ]; then
  exec "$@"
fi
echo "=== container startup: verify GPU/runtime ==="
python3 /usr/local/bin/verify-gpu.py || true
if [ -x /ollama ]; then
  echo "Starting Ollama (portable) -> /ollama serve"
  exec /ollama serve
else
  echo "/ollama not found; dropping to bash"
  exec /bin/bash
fi
SH
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 11434
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
