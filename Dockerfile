# ============================================================
# Intel-Optimized Ollama + IPEX-LLM + OpenVINO + OVMS Container
# Target: Unraid host with Arc A770 × 2 + AMD 5950X
# Base: Intel oneAPI 2025.3.0 Ubuntu 24.04
# ============================================================

FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles \
    OLLAMA_HOST=0.0.0.0:11434 \
    SYCL_DEVICE_FILTER=level_zero:gpu \
    ONEAPI_DEVICE_SELECTOR=level_zero:gpu \
    ZES_ENABLE_SYSMAN=1 \
    IPEX_LLM_GPU_RUNTIME=level_zero \
    OLLAMA_FLASH_ATTENTION=1 \
    OLLAMA_NUM_CPU=32 \
    OLLAMA_KEEP_ALIVE=0

# ------------------------------------------------------------
# System setup and Intel GPU user-space drivers
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget curl gnupg ca-certificates \
        python3 python3-pip python3-dev python3-venv python3-wheel \
        git libglib2.0-0 libsm6 libxext6 libxrender-dev \
        ocl-icd-libopencl1 && \
    rm -rf /var/lib/apt/lists/*

# Add Intel Graphics repository for up-to-date GPU runtimes
RUN set -eux; \
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg; \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu noble arc" \
        > /etc/apt/sources.list.d/intel-graphics.list; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        intel-opencl-icd intel-level-zero-gpu \
        level-zero intel-igc-core intel-igc-opencl \
        libigdgmm12 intel-ocloc && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Python setup (allow pip inside OneAPI base container)
# ------------------------------------------------------------
RUN set -eux; \
    python3 -m ensurepip || true; \
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel --break-system-packages

# ------------------------------------------------------------
# Install PyTorch + Intel Extension for PyTorch (IPEX)
# ------------------------------------------------------------
RUN set -eux; \
    echo "Installing PyTorch + Intel IPEX for XPU..."; \
    python3 -m pip install --no-cache-dir \
        --break-system-packages \
        --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/ \
        torch==2.3.1 torchvision==0.18.1 intel-extension-for-pytorch==2.3.110+xpu

# ------------------------------------------------------------
# Install OpenVINO and Model Server
# ------------------------------------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir --break-system-packages \
        openvino==2024.3.0 openvino-dev==2024.3.0; \
    wget -q https://storage.openvinotoolkit.org/repositories/openvino-model-server/releases/2024/ovms_ubuntu22.tar.gz -O /tmp/ovms.tar.gz; \
    mkdir -p /opt/ovms && tar -xzf /tmp/ovms.tar.gz -C /opt/ovms --strip-components=1; \
    rm /tmp/ovms.tar.gz

# ------------------------------------------------------------
# Install IPEX-LLM runtime (Ollama portable)
# ------------------------------------------------------------
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=ollama-ipex-llm-2.2.0-ubuntu.tgz
RUN set -eux; \
    cd / && \
    wget -q https://github.com/intel/ipex-llm/releases/download/v2.2.0/${IPEXLLM_PORTABLE_ZIP_FILENAME}; \
    tar xvf ${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C /; \
    rm ${IPEXLLM_PORTABLE_ZIP_FILENAME}

# ------------------------------------------------------------
# Environment tuning for AMD + Intel hybrid host
# ------------------------------------------------------------
ENV OMP_NUM_THREADS=32 \
    KMP_BLOCKTIME=1 \
    KMP_AFFINITY=granularity=fine,compact,1,0 \
    MALLOC_ARENA_MAX=1

# ------------------------------------------------------------
# Expose Ollama + OVMS ports
# ------------------------------------------------------------
EXPOSE 11434 9000

# ------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------
ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
