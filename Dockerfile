FROM ollama/ollama:latest

# Add Intel GPU support to the official image
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        wget \
        gnupg && \
    wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | gpg --dearmor > /usr/share/keyrings/intel-graphics.gpg && \
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy/production/2328 unified' > /etc/apt/sources.list.d/intel-gpu.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        intel-opencl-icd \
        intel-level-zero-gpu && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Intel Arc GPU environment variables
ENV OLLAMA_GPU_DRIVER=rocm
ENV HSA_OVERRIDE_GFX_VERSION=10.3.0
ENV OLLAMA_HOST=0.0.0.0

# The official image already has the entrypoint configured
