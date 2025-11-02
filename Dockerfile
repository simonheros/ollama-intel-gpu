# =============================================================================
# 🧠  Intel-Optimized Ollama + IPEX-LLM Portable Build  (Ubuntu 24.04)
# =============================================================================

FROM ubuntu:24.04

# -----------------------------------------------------------------------------
# 0. Environment setup
# -----------------------------------------------------------------------------
ARG DEBIAN_FRONTEND=noninteractive
ARG IPEXLLM_VERSION=2.2.0
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=llama-cpp-ipex-llm-${IPEXLLM_VERSION}-ubuntu-core.tgz

ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

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
        pciutils \
        clinfo \
        tar \
        bzip2 \
        xz-utils \
        vim \
        less \
        git \
        python3 \
        python3-pip \
        python3-venv && \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Intel GPU runtimes (APT repo with automatic fallback)
# -----------------------------------------------------------------------------
RUN set -eux; \
    echo "🔧 Adding Intel GPU repository (using Jammy repo for 24.04 compatibility)"; \
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
        echo "⚠️ Intel APT install failed — falling back to manual .deb installation."; \
        mkdir -
