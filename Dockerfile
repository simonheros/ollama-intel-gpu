# ============================================================
#   Intel OneAPI + OpenVINO + GPU Runtime + OVMS Base Image
# ============================================================
FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

# ------------------------------------------------------------
# System dependencies and Intel GPU runtime setup
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget curl gnupg2 ca-certificates apt-transport-https \
        software-properties-common lsb-release build-essential \
        python3 python3-pip python3-venv python3-dev git vim && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Add Intel Graphics repository for GPU runtimes
# ------------------------------------------------------------
RUN set -eux; \
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
        gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg; \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
        https://repositories.intel.com/graphics/ubuntu jammy arc" \
        > /etc/apt/sources.list.d/intel-graphics.list; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        intel-opencl-icd intel-level-zero-gpu level-zero libigdgmm12 && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Upgrade pip and core Python build tools
# ------------------------------------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# ------------------------------------------------------------
# Install OpenVINO + Model Server (OVMS)
# ------------------------------------------------------------
RUN set -eux; \
    pip install --no-cache-dir openvino==2024.3.0 openvino-dev==2024.3.0; \
    cd /tmp && \
    wget -q https://github.com/openvinotoolkit/model_server/releases/download/v2024.3.0/ovms_ubuntu22.tar.gz -O ovms.tar.gz; \
    mkdir -p /opt/ovms && tar -xzf ovms.tar.gz -C /opt/ovms --strip-components=1; \
    rm ovms.tar.gz

# ------------------------------------------------------------
# Set PATH and environment
# ------------------------------------------------------------
ENV PATH="/opt/ovms/bin:$PATH"

# ------------------------------------------------------------
# Default command (interactive shell)
# ------------------------------------------------------------
CMD ["/bin/bash"]
