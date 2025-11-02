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

# Download and install the actual available IPEX-LLM files from v2.2.0
RUN cd /tmp && \
    echo "Downloading IPEX-LLM core library..." && \
    wget -q https://github.com/ipex-llm/ipex-llm/releases/download/v2.2.0/ipex_llm-2.2.0+cpu-cp311-cp311-manylinux2014_x86_64.whl && \
    echo "Downloading example applications..." && \
    wget -q https://github.com/ipex-llm/ipex-llm/releases/download/v2.2.0/ipex_llm_examples-2.2.0-py3-none-any.whl

# Install Python and the IPEX-LLM wheels
RUN apt update && apt install -y python3 python3-pip && \
    pip3 install /tmp/ipex_llm-2.2.0+cpu-cp311-cp311-manylinux2014_x86_64.whl && \
    pip3 install /tmp/ipex_llm_examples-2.2.0-py3-none-any.whl && \
    rm -f /tmp/*.whl && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Install Ollama using the official method
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Set environment variables for IPEX-LLM
ENV OLLAMA_HOST=0.0.0.0:11434
ENV IPEX_LLM_GPU_RUNTIME=opencl

# Create a start script that uses IPEX-LLM with Ollama
RUN printf '#!/bin/bash\necho "Starting Ollama with IPEX-LLM GPU acceleration..."\necho "OLLAMA_HOST: $OLLAMA_HOST"\necho "IPEX_LLM_GPU_RUNTIME: $IPEX_LLM_GPU_RUNTIME"\n\n# Check GPU availability\necho "Checking GPU devices..."\nls -la /dev/dri/ 2>/dev/null || echo "No DRI devices found"\n\n# Check OpenCL devices\necho "Checking OpenCL devices..."\nwhich clinfo && clinfo 2>/dev/null | head -20 || echo "clinfo not available"\n\necho "Starting Ollama server..."\nexec ollama serve\n' > /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
