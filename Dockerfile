FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=america/los_angeles

# Base packages
RUN apt update && \
    apt install --no-install-recommends -q -y \
    software-properties-common \
    ca-certificates \
    wget \
    ocl-icd-libopencl1

# Intel GPU compute user-space drivers - using consistent versions
RUN mkdir -p /tmp/gpu && \
    cd /tmp/gpu && \
    wget https://github.com/oneapi-src/level-zero/releases/download/v1.25.2/level-zero_1.25.2+u24.04_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-core-2_2.20.3+19972_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-opencl-2_2.20.3+19972_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-ocloc_25.40.35563.4-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-opencl-icd_25.40.35563.4-0_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libigdgmm12_22.8.2_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libze-intel-gpu1_25.40.35563.4-0_amd64.deb && \
    apt install -y ./level-zero_1.25.2+u24.04_amd64.deb && \
    apt install -y ./intel-igc-core-2_2.20.3+19972_amd64.deb && \
    apt install -y ./intel-igc-opencl-2_2.20.3+19972_amd64.deb && \
    apt install -y ./libigdgmm12_22.8.2_amd64.deb && \
    apt install -y ./intel-ocloc_25.40.35563.4-0_amd64.deb && \
    apt install -y ./intel-opencl-icd_25.40.35563.4-0_amd64.deb && \
    apt install -y ./libze-intel-gpu1_25.40.35563.4-0_amd64.deb && \
    cd / && \
    rm -rf /tmp/gpu

# Download and install IPEX-LLM Ollama with multiple fallbacks
RUN cd /tmp && \
    # Try direct download first
    (wget -q https://github.com/intel/ipex-llm/releases/download/v2.2.0/ollama-ipex-llm-2.2.0-ubuntu.tgz || \
    curl -L -o ollama-ipex-llm-2.2.0-ubuntu.tgz https://github.com/intel/ipex-llm/releases/download/v2.2.0/ollama-ipex-llm-2.2.0-ubuntu.tgz) && \
    # Extract to root
    tar xvf ollama-ipex-llm-2.2.0-ubuntu.tgz --strip-components=1 -C / && \
    rm -f ollama-ipex-llm-2.2.0-ubuntu.tgz

ENV OLLAMA_HOST=0.0.0.0:11434

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
