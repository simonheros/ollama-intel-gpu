FROM ubuntu:24.04

# Noninteractive mode (no prompts)
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=America/Los_Angeles \
    OLLAMA_HOST=0.0.0.0:11434

# -----------------------------------------------------------------------------
# 1. Base system setup
# -----------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        wget \
        software-properties-common \
        ocl-icd-libopencl1 \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Install Intel GPU compute runtime (Level Zero, OpenCL, etc.)
# -----------------------------------------------------------------------------
RUN set -eux; \
    mkdir -p /tmp/gpu && cd /tmp/gpu; \
    wget -q https://github.com/oneapi-src/level-zero/releases/download/v1.25.2/level-zero_1.25.2+u24.04_amd64.deb; \
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-core-2_2.20.3+19972_amd64.deb; \
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-opencl-2_2.20.3+19972_amd64.deb; \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.09.32961.7/intel-level-zero-gpu_1.6.32961.7_amd64.deb; \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-ocloc_25.40.35563.4-0_amd64.deb; \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-opencl-icd_25.40.35563.4-0_amd64.deb; \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libigdgmm12_22.8.2_amd64.deb; \
    wget -q https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libze-intel-gpu1_25.40.35563.4-0_amd64.deb; \
    dpkg -i *.deb || true; \
    apt-get update; \
    apt-get install -fy; \
    dpkg -i *.deb; \
    rm -rf /tmp/gpu /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 3. Install IPEX-LLM Ollama portable package
# -----------------------------------------------------------------------------
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=ollama-ipex-llm-2.2.0-ubuntu.tgz

RUN cd / && \
    wget -q https://github.com/intel/ipex-llm/releases/download/v2.2.0/${IPEXLLM_PORTABLE_ZIP_FILENAME} && \
    tar xvf ${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C / && \
    rm ${IPEXLLM_PORTABLE_ZIP_FILENAME}

# -----------------------------------------------------------------------------
# 4. Runtime entrypoint
# -----------------------------------------------------------------------------
EXPOSE 11434
ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
