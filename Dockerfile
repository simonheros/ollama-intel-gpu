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
    git \
    build-essential \
    ocl-icd-libopencl1 && \
    clinfo && \
    intel-opencl-icd && \
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

# Install Intel GPU drivers from Intel's official repository
RUN wget -q -O - https://repositories.intel.com/gpu/intel-graphics.key | gpg --dearmor > /usr/share/keyrings/intel-graphics.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" > /etc/apt/sources.list.d/intel-gpu.list && \
    apt update && \
    apt install -y intel-opencl-icd intel-level-zero-gpu level-zero level-zero-devel && \
    apt clean && rm -rf /var/lib/apt/lists/*

# Install Python and basic dependencies first
RUN apt update && \
    apt install -y python3 python3-pip python3-venv && \
    apt clean && \
    rm -rf /var/lib/apt/lists/*

# Install Ollama using the official method
RUN curl -fsSL https://ollama.ai/install.sh | sh

# Set environment variables
ENV OLLAMA_HOST=0.0.0.0:11434

# Create start script without IPEX-LLM for now
RUN printf '#!/bin/bash\necho "Starting Ollama with Intel GPU support..."\necho "OLLAMA_HOST: $OLLAMA_HOST"\necho ""\necho "Checking GPU devices:"\nls -la /dev/dri/ 2>/dev/null || echo "No DRI devices found"\necho ""\necho "Starting Ollama server..."\nexec ollama serve\n' > /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
