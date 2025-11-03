# ============================================================
# Intel OneAPI + PyTorch + OpenVINO + Ollama container
# Stable and GitHub Actions–friendly build
# ============================================================

FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# ------------------------------------------------------------
# System setup
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv python3-dev \
        git wget curl ca-certificates gnupg lsb-release \
        build-essential cmake pkg-config \
        && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Upgrade pip and build tools
# ------------------------------------------------------------
RUN set -eux; \
    python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel

# ------------------------------------------------------------
# Install PyTorch CPU build + Intel Extensions + OpenVINO
# ------------------------------------------------------------
RUN set -eux; \
    # Install PyTorch CPU wheels from official index
    pip install --no-cache-dir \
        torch==2.3.1+cpu \
        torchvision==0.18.1+cpu \
        torchaudio==2.3.1+cpu \
        --index-url https://download.pytorch.org/whl/cpu && \
    \
    # Install Intel extensions and OpenVINO ecosystem
    pip install --no-cache-dir \
        intel-extension-for-pytorch==2.3.100 \
        ipex-llm==2.2.0 \
        openvino==2024.3.0 \
        openvino-dev==2024.3.0 \
        numpy==1.26.4 \
        requests==2.32.3

# ------------------------------------------------------------
# Install Ollama
# ------------------------------------------------------------
RUN set -eux; \
    curl -fsSL https://ollama.com/install.sh | sh

# ------------------------------------------------------------
# Clean up
# ------------------------------------------------------------
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ------------------------------------------------------------
# Default working directory
# ------------------------------------------------------------
WORKDIR /workspace

# ------------------------------------------------------------
# Default command
# ------------------------------------------------------------
CMD ["/bin/bash"]
