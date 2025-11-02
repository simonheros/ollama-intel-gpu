FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Base packages and Intel GPU setup in single layer
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

# Remove the manual .deb installation section - it's redundant and causes conflicts
# The repository approach above already installs these packages properly

# Install Ollama Portable Zip
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=ollama-ipex-llm-2.2.0-ubuntu.tgz
RUN cd / && \
    wget https://github.com/intel/ipex-llm/releases/download/v2.2.0/${IPEXLLM_PORTABLE_ZIP_FILENAME} && \
    tar xvf ${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C / && \
    rm ${IPEXLLM_PORTABLE_ZIP_FILENAME}

ENV OLLAMA_HOST=0.0.0.0:11434

# Create the missing start script
RUN echo '#!/bin/bash' > /start-ollama.sh && \
    echo 'echo "Starting Ollama with Intel IPEX-LLM support..."' >> /start-ollama.sh && \
    echo 'ollama serve' >> /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
