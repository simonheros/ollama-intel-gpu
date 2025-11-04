# ============================================================
# Base image: Intel oneAPI 2025.3.0 for Ubuntu 22.04
# ============================================================
FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Install GPU diagnostics and system utilities
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        pciutils \
        usbutils \
        clinfo \
        vainfo \
        mesa-utils \
        hwloc \
        wget \
        curl \
        vim \
        less \
        jq \
        python3-pip \
        python3-setuptools && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Install Intel GPU runtime components
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ocl-icd-libopencl1 \
        intel-opencl-icd \
        intel-level-zero-gpu && \
    rm -rf /var/lib/apt/lists/* || echo "Some packages may not be available, continuing..."

# ------------------------------------------------------------
# Install Python dependencies for Intel PyTorch + OpenVINO
# ------------------------------------------------------------
RUN set -eux; \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
        numpy==1.26.4 \
        requests==2.32.3 && \
    rm -rf /root/.cache/pip

# Install PyTorch with Intel extensions
RUN set -eux; \
    pip install --no-cache-dir \
        torch==2.3.1 \
        torchvision==0.18.1 \
        torchaudio==2.3.1 \
        --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir \
        intel-extension-for-pytorch==2.3.100 \
        ipex-llm==2.2.0 && \
    rm -rf /root/.cache/pip

# Install OpenVINO
RUN set -eux; \
    pip install --no-cache-dir \
        openvino==2024.3.0 \
        openvino-dev==2024.3.0 && \
    rm -rf /root/.cache/pip

# ------------------------------------------------------------
# Environment configuration
# ------------------------------------------------------------
ENV SYCL_DEVICE_FILTER=level_zero:gpu \
    ONEAPI_DEVICE_SELECTOR=level_zero:gpu \
    ZES_ENABLE_SYSMAN=1 \
    SYCL_PI_LEVEL_ZERO_USE_MULTI_DEVICE_CONTEXT=1 \
    SYCL_QUEUE_THREAD_POOL_SIZE=16 \
    IPEX_LLM_GPU_RUNTIME=level_zero \
    TORCH_DEVICE=xpu \
    OMP_NUM_THREADS=16 \
    MKL_NUM_THREADS=16 \
    KMP_AFFINITY="granularity=fine,compact,1,0" \
    OPENVINO_DEVICE=GPU \
    OPENVINO_LOG_LEVEL=INFO

# ------------------------------------------------------------
# Default command
# ------------------------------------------------------------
CMD ["/usr/local/bin/start-container"]
