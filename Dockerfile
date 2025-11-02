FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Base packages and Intel GPU setup
RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        software-properties-common \
        ca-certificates \
        wget \
        gnupg \
        ocl-icd-libopencl1 && \
    wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | gpg --dearmor > /usr/share/keyrings/intel-graphics.gpg && \
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy/production/2328 unified' > /etc/apt/sources.list.d/intel-gpu.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y \
        intel-opencl-icd \
        intel-level-zero-gpu \
        level-zero \
        level-zero-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Ollama - Use official Ollama instead of IPEX-LLM portable
RUN wget https://ollama.com/download/ollama-linux-amd64 && \
    chmod +x ollama-linux-amd64 && \
    mv ollama-linux-amd64 /usr/local/bin/ollama

# Or if you specifically need IPEX-LLM, use the correct filename:
# RUN wget https://github.com/intel/ipex-llm/releases/download/v2.2.0/llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz && \
#     tar xvf llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz --strip-components=1 -C / && \
#     rm llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz

ENV OLLAMA_HOST=0.0.0.0:11434

# Create start script
RUN echo '#!/bin/bash' > /start-ollama.sh && \
    echo 'echo "Starting Ollama with Intel GPU support..."' >> /start-ollama.sh && \
    echo 'ollama serve' >> /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
