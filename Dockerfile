FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Update and install all necessary packages
RUN apt update && \
    apt install --no-install-recommends -q -y \
    software-properties-common \
    ca-certificates \
    wget \
    curl \
    ocl-icd-libopencl1 && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Intel GPU compute user-space drivers
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

# Download IPEX-LLM and extract with better debugging
RUN cd /tmp && \
    echo "Downloading IPEX-LLM..." && \
    wget -q --tries=3 --timeout=60 https://github.com/intel/ipex-llm/releases/download/v2.2.0/llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz && \
    echo "Extracting archive..." && \
    tar -tzf llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz && \
    echo "Full extraction..." && \
    tar xzf llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz -C / && \
    rm -f llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz && \
    echo "Looking for ollama binary..." && \
    find / -name "ollama" -type f 2>/dev/null

# Set PATH to include common binary locations
ENV PATH="/usr/local/bin:/bin:/usr/bin:/app:/ollama:${PATH}"

ENV OLLAMA_HOST=0.0.0.0:11434

# Create a more robust start script
RUN printf '#!/bin/bash\nset -e\necho "Starting Ollama with IPEX-LLM..."\necho "OLLAMA_HOST: $OLLAMA_HOST"\n\n# Find ollama binary\nOLLAMA_BIN=$(find / -name "ollama" -type f 2>/dev/null | head -1)\nif [ -z "$OLLAMA_BIN" ]; then\n    echo "Error: ollama binary not found!"\n    echo "Searching for executable files..."\n    find / -type f -executable -name "*ollama*" 2>/dev/null | head -10\n    exit 1\nfi\n\necho "Found ollama at: $OLLAMA_BIN"\necho "Starting Ollama server..."\nexec "$OLLAMA_BIN" serve\n' > /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
