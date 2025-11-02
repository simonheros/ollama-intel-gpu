FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Update and install all necessary packages in one layer
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

# Download IPEX-LLM in a separate step with verification
RUN cd /tmp && \
    echo "Downloading IPEX-LLM Ollama..." && \
    if ! wget -q --tries=3 --timeout=60 https://github.com/intel/ipex-llm/releases/download/v2.2.0/ollama-ipex-llm-2.2.0-ubuntu.tgz; then \
        echo "wget failed, trying curl..." && \
        curl -L -f -o ollama-ipex-llm-2.2.0-ubuntu.tgz https://github.com/intel/ipex-llm/releases/download/v2.2.0/ollama-ipex-llm-2.2.0-ubuntu.tgz; \
    fi && \
    echo "Verifying download..." && \
    if [ ! -f "ollama-ipex-llm-2.2.0-ubuntu.tgz" ]; then \
        echo "Download failed - file not found"; \
        exit 1; \
    fi && \
    echo "Extracting..." && \
    tar xvf ollama-ipex-llm-2.2.0-ubuntu.tgz --strip-components=1 -C / && \
    rm -f ollama-ipex-llm-2.2.0-ubuntu.tgz && \
    echo "Extraction completed"

ENV OLLAMA_HOST=0.0.0.0:11434

# Create start script
RUN cat > /start-ollama.sh << 'EOF'
#!/bin/bash
echo "Starting Ollama with IPEX-LLM..."
echo "OLLAMA_HOST: $OLLAMA_HOST"
exec ollama serve
EOF

RUN chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
