# ============================================================
#  Base: Ubuntu 22.04 with Python and Intel GPU runtime
# ============================================================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app

# ------------------------------------------------------------
# 1. System dependencies + Intel graphics repo setup
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget curl ca-certificates gnupg software-properties-common lsb-release python3 python3-pip python3-venv python3-dev build-essential && \
    \
    # Add Intel Graphics repository (for OpenCL + Level Zero)
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
        gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
        https://repositories.intel.com/graphics/ubuntu jammy arc" \
        > /etc/apt/sources.list.d/intel-graphics.list && \
    apt-get update && \
    \
    # Install Intel GPU runtime libraries safely (handle unmet deps)
    apt-get install -y --no-install-recommends \
        intel-opencl-icd \
        intel-level-zero-gpu \
        level-zero \
        libigdgmm12 || true && \
    \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# 2. Upgrade pip tooling
# ------------------------------------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# ------------------------------------------------------------
# 3. Install PyTorch (CPU build) + Intel extensions
# ------------------------------------------------------------
RUN set -eux; \
    # Install PyTorch CPU wheels from official index
    pip install --no-cache-dir \
        torch==2.3.1+cpu \
        torchvision==0.18.1+cpu \
        torchaudio==2.3.1+cpu \
        --index-url https://download.pytorch.org/whl/cpu && \
    \
    # Then Intel-specific optimizations (correct version)
    pip install --no-cache-dir \
        intel-extension-for-pytorch==2.3.0 \
        ipex-llm==2.2.0 \
        openvino==2024.3.0 \
        openvino-dev==2024.3.0 \
        numpy==1.26.4 \
        requests==2.32.3

# ------------------------------------------------------------
# 4. Install OpenVINO Model Server (OVMS)
# ------------------------------------------------------------
RUN set -eux; \
    wget -q https://storage.openvinotoolkit.org/repositories/openvino-model-server/releases/2024/ovms_ubuntu22.tar.gz -O /tmp/ovms.tar.gz || \
    (echo "Failed to download OVMS tarball"; exit 1); \
    \
    mkdir -p /opt/ovms && \
    tar -xzf /tmp/ovms.tar.gz -C /opt/ovms --strip-components=1 || \
    (echo "OVMS tarball is not gzip format — check URL or release"; exit 1); \
    \
    rm /tmp/ovms.tar.gz

# ------------------------------------------------------------
# 5. Cleanup
# ------------------------------------------------------------
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /root/.cache

# ------------------------------------------------------------
# 6. Default entrypoint
# ------------------------------------------------------------
COPY . /app
CMD ["python3", "main.py"]
