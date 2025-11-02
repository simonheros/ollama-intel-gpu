FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Install base system packages
RUN apt update && \
    apt install -y \
    ca-certificates \
    wget \
    curl && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Install ONLY the essential Level Zero packages (no OpenCL)
RUN mkdir -p /tmp/gpu && cd /tmp/gpu && \
    # Install only Level Zero core packages
    wget -q https://github.com/oneapi-src/level-zero/releases/download/v1.25.2/level-zero_1.25.2+u24.04_amd64.deb && \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libze-intel-gpu1_25.40.35563.4-0_amd64.deb && \
    # Install only these two packages (skip OpenCL packages)
    apt install -y ./level-zero_1.25.2+u24.04_amd64.deb ./libze-intel-gpu1_25.40.35563.4-0_amd64.deb && \
    cd / && rm -rf /tmp/gpu

# Install IPEX-LLM Ollama from official Intel release
RUN cd /tmp && \
    wget -q https://github.com/intel/ipex-llm/releases/download/v2.2.0/ollama-ipex-llm-2.2.0-ubuntu.tgz && \
    tar xzf ollama-ipex-llm-2.2.0-ubuntu.tgz --strip-components=1 -C / && \
    rm -f ollama-ipex-llm-2.2.0-ubuntu.tgz
    
# Verify Ollama installation
RUN chmod +x /usr/local/bin/ollama && \
    mkdir -p /root/.ollama

# Set environment variables for Level Zero
ENV OLLAMA_HOST=0.0.0.0:11434
ENV SYCL_DEVICE_FILTER=level_zero:gpu
ENV ONEAPI_DEVICE_SELECTOR=level_zero:gpu
ENV ZES_ENABLE_SYSMAN=1

# Create startup script
RUN printf '#!/bin/bash\necho "=== Intel IPEX-LLM Ollama === "\necho "Using Level Zero backend for Intel GPUs"\necho ""\necho "Starting Ollama with Intel GPU acceleration..."\nexec ollama serve\n' > /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
