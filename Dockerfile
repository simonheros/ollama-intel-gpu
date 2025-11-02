FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Install base system packages
RUN apt update && \
    apt install -y \
    software-properties-common \
    ca-certificates \
    wget \
    curl && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Install Intel GPU drivers from manual .deb files only
RUN mkdir -p /tmp/gpu && cd /tmp/gpu && \
    wget -q https://github.com/oneapi-src/level-zero/releases/download/v1.25.2/level-zero_1.25.2+u24.04_amd64.deb && \
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-core-2_2.20.3+19972_amd64.deb && \
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-opencl-2_2.20.3+19972_amd64.deb && \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-ocloc_25.40.35563.4-0_amd64.deb && \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-opencl-icd_25.40.35563.4-0_amd64.deb && \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libigdgmm12_22.8.2_amd64.deb && \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libze-intel-gpu1_25.40.35563.4-0_amd64.deb && \
    apt install -y ./*.deb && \
    cd / && rm -rf /tmp/gpu

# Install IPEX-LLM Ollama from official Intel release
RUN cd /tmp && \
    wget -q https://github.com/intel/ipex-llm/releases/download/v2.2.0/ollama-ipex-llm-2.2.0-ubuntu.tgz && \
    tar xzf ollama-ipex-llm-2.2.0-ubuntu.tgz --strip-components=1 -C / && \
    rm -f ollama-ipex-llm-2.2.0-ubuntu.tgz
    
# Verify Ollama installation and set permissions
RUN chmod +x /usr/local/bin/ollama && \
    mkdir -p /root/.ollama

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0:11434
ENV SYCL_DEVICE_FILTER=level_zero:gpu
ENV ONEAPI_DEVICE_SELECTOR=level_zero:gpu
ENV ZES_ENABLE_SYSMAN=1

# Create startup script
RUN printf '#!/bin/bash\necho "=== Intel IPEX-LLM Ollama === "\necho "Using Level Zero backend for Intel GPUs"\necho ""\necho "GPU Devices:"\nls -la /dev/dri/ 2>/dev/null || echo "No DRI devices"\necho ""\necho "Starting Ollama with Intel GPU acceleration..."\nexec ollama serve\n' > /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
