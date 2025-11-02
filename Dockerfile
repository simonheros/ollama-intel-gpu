# =============================================================================
# 🧠 Intel-Optimized Ollama + IPEX-LLM + OpenVINO + PyTorch-IPEX
#      Ubuntu 24.04 (Noble) base with Intel GPU acceleration
#      + Flexible entrypoint (diagnostics or serve)
# =============================================================================

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG IPEXLLM_VERSION=2.2.0
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=llama-cpp-ipex-llm-${IPEXLLM_VERSION}-ubuntu-core.tgz

ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PATH="/usr/local/bin:${PATH}" \
    LD_LIBRARY_PATH="/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"

# -----------------------------------------------------------------------------
# 1. Base system dependencies
# -----------------------------------------------------------------------------
RUN set -eux; \
    apt-get update -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        gnupg \
        gpg-agent \
        lsb-release \
        software-properties-common \
        pciutils \
        clinfo \
        tar \
        bzip2 \
        xz-utils \
        git \
        vim \
        less \
        python3 \
        python3-pip \
        python3-venv && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Intel GPU Runtime (APT repo + fallback)
# -----------------------------------------------------------------------------
RUN set -eux; \
    echo "🔧 Adding Intel GPU repo (using Jammy for compatibility)"; \
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
        gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg; \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
        https://repositories.intel.com/graphics/ubuntu jammy arc" \
        > /etc/apt/sources.list.d/intel-graphics.list; \
    apt-get update || true; \
    if ! apt-get install -y --no-install-recommends \
        intel-opencl-icd \
        intel-level-zero-gpu \
        level-zero \
        intel-igc-core \
        intel-igc-opencl \
        libigdgmm12 \
        intel-ocloc; then \
        echo "⚠️ Intel repo failed — falling back to manual .deb install"; \
        mkdir -p /tmp/gpu && cd /tmp/gpu; \
        wget -q https://github.com/oneapi-src/level-zero/releases/download/v1.25.2/level-zero_1.25.2+u24.04_amd64.deb; \
        wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-core-2_2.20.3+19972_amd64.deb; \
        wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-opencl-2_2.20.3+19972_amd64.deb; \
        wget -q https://github.com/intel/compute-runtime/releases/download/25.09.32961.7/intel-level-zero-gpu_1.6.32961.7_amd64.deb; \
        wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-ocloc_25.40.35563.4-0_amd64.deb; \
        wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-opencl-icd_25.40.35563.4-0_amd64.deb; \
        wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libigdgmm12_22.8.2_amd64.deb; \
        wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libze-intel-gpu1_25.40.35563.4-0_amd64.deb; \
        dpkg -i *.deb || true; apt-get install -fy; dpkg -i *.deb; \
        cd / && rm -rf /tmp/gpu; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 3. IPEX-LLM portable Ollama
# -----------------------------------------------------------------------------
RUN set -eux; \
    echo "⬇️ Installing IPEX-LLM portable ${IPEXLLM_VERSION}"; \
    cd /; \
    wget -q https://github.com/intel/ipex-llm/releases/download/v${IPEXLLM_VERSION}/${IPEXLLM_PORTABLE_ZIP_FILENAME} || \
        (echo "❌ Failed to download ${IPEXLLM_PORTABLE_ZIP_FILENAME}" && exit 1); \
    tar xvf ${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C /; \
    rm ${IPEXLLM_PORTABLE_ZIP_FILENAME}

# -----------------------------------------------------------------------------
# 4. Intel OpenVINO Runtime + PyTorch-IPEX
# -----------------------------------------------------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel; \
    python3 -m pip install --no-cache-dir \
        openvino==2024.5.0 \
        torch==2.3.1 \
        torchvision==0.18.1 \
        intel-extension-for-pytorch==2.3.110+xpu \
        numpy scipy psutil && \
    python3 -m pip cache purge

# -----------------------------------------------------------------------------
# 5. Entry point scripts
# -----------------------------------------------------------------------------
COPY <<'EOF' /usr/local/bin/verify_intel_gpu.py
#!/usr/bin/env python3
import torch, subprocess
from openvino.runtime import Core

print("=== Intel Runtime Verification ===")
# Check OpenCL device
try:
    result = subprocess.run(["clinfo"], capture_output=True, text=True)
    if "Intel" in result.stdout:
        print("✅ OpenCL: Intel GPU detected")
    else:
        print("⚠️ OpenCL: No Intel GPU found")
except Exception as e:
    print(f"❌ OpenCL check failed: {e}")
# Check PyTorch + IPEX
try:
    import intel_extension_for_pytorch as ipex
    print(f"✅ PyTorch {torch.__version__}, IPEX {ipex.__version__}")
    print(f"   XPU available: {torch.xpu.is_available()}")
except Exception as e:
    print(f"❌ IPEX check failed: {e}")
# Check OpenVINO
try:
    ie = Core()
    devices = ie.available_devices
    print(f"✅ OpenVINO devices: {devices}")
except Exception as e:
    print(f"❌ OpenVINO check failed: {e}")
print("==================================")
EOF

COPY <<'EOF' /usr/local/bin/entrypoint.sh
#!/bin/bash
set -e

if [ $# -eq 0 ]; then
  echo "=== Intel GPU Environment Verification ==="
  /usr/bin/python3 /usr/local/bin/verify_intel_gpu.py || true
  echo "=========================================="
  echo "🚀 Starting Ollama (IPEX-LLM portable)..."
  exec /ollama serve
else
  echo "➡️ Executing user command: $@"
  exec "$@"
fi
EOF

RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/verify_intel_gpu.py

# -----------------------------------------------------------------------------
# 6. Entrypoint
# -----------------------------------------------------------------------------
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
