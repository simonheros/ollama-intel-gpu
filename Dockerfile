# ============================================================
# Intel-Optimized Ollama + PyTorch/IPEX-LLM + OpenVINO + OVMS
# Base: OneAPI Base Kit 2025.3 (Ubuntu 22.04)
# ============================================================

FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles

# ------------------------------------------------------------
# Core utilities and dependencies
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget curl ca-certificates gnupg2 \
        lsb-release pciutils usbutils clinfo \
        python3 python3-pip python3-venv \
        software-properties-common \
        ocl-icd-libopencl1 && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Intel GPU runtime stack (Level Zero + OpenCL)
# ------------------------------------------------------------
RUN set -eux; \
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
        gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg; \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
        https://repositories.intel.com/graphics/ubuntu jammy arc" \
        > /etc/apt/sources.list.d/intel-graphics.list; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        intel-opencl-icd \
        intel-media-va-driver-non-free \
        libmfx1 libmfxgen1 libvpl2 \
        level-zero vainfo && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Upgrade pip and build tools
# ------------------------------------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# ------------------------------------------------------------
# Install PyTorch + IPEX + IPEX-LLM (Intel Optimized)
# ------------------------------------------------------------
RUN set -eux; \
    pip install --no-cache-dir \
        torch==2.3.1+cpu \
        torchvision==0.18.1+cpu \
        torchaudio==2.3.1+cpu \
        intel-extension-for-pytorch==2.3.1+xpu \
        ipex-llm==2.2.0 \
        openvino==2024.3.0 openvino-dev==2024.3.0 \
        numpy==1.26.4 requests==2.32.3

# ------------------------------------------------------------
# Install OpenVINO Model Server (OVMS)
# ------------------------------------------------------------
RUN set -eux; \
    wget -q https://storage.openvinotoolkit.org/repositories/openvino-model-server/releases/2024/ovms_ubuntu22.tar.xz -O /tmp/ovms.tar.xz; \
    mkdir -p /opt/ovms && \
    tar -xJf /tmp/ovms.tar.xz -C /opt/ovms --strip-components=1 && \
    rm /tmp/ovms.tar.xz

ENV PATH="/opt/ovms/bin:$PATH"

# ------------------------------------------------------------
# Install Intel IPEX-LLM portable Ollama bundle
# ------------------------------------------------------------
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=ollama-ipex-llm-2.2.0-ubuntu.tgz
RUN set -eux; \
    cd / && \
    wget https://github.com/intel/ipex-llm/releases/download/v2.2.0/${IPEXLLM_PORTABLE_ZIP_FILENAME} && \
    tar xvf ${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C / && \
    rm ${IPEXLLM_PORTABLE_ZIP_FILENAME}

# ------------------------------------------------------------
# Environment variables and entrypoint
# ------------------------------------------------------------
ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/root/.ollama/models \
    PATH="/opt/ovms/bin:/opt/intel/oneapi/compiler/latest/linux/bin:$PATH"

EXPOSE 11434

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
