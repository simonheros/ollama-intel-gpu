FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

# Install base system packages
RUN apt update && \
    apt install --no-install-recommends -q -y \
    software-properties-common \
    ca-certificates \
    wget \
    ocl-icd-libopencl1

# Intel GPU compute user-space drivers
RUN mkdir -p /tmp/gpu && \
 cd /tmp/gpu && \
 wget https://github.com/oneapi-src/level-zero/releases/download/v1.25.2/level-zero_1.25.2+u24.04_amd64.deb && \ 
 wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-core-2_2.20.3+19972_amd64.deb && \
 wget https://github.com/intel/intel-graphics-compiler/releases/download/v2.20.3/intel-igc-opencl-2_2.20.3+19972_amd64.deb && \
 wget https://github.com/intel/compute-runtime/releases/download/25.09.32961.7/intel-level-zero-gpu_1.6.32961.7_amd64.deb && \
 wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-ocloc-dbgsym_25.40.35563.4-0_amd64.ddeb  && \
 wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-ocloc_25.40.35563.4-0_amd64.deb  && \
 wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-opencl-icd-dbgsym_25.40.35563.4-0_amd64.ddeb  && \
 wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/intel-opencl-icd_25.40.35563.4-0_amd64.deb  && \
 wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libigdgmm12_22.8.2_amd64.deb && \
 wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libze-intel-gpu1-dbgsym_25.40.35563.4-0_amd64.ddeb  && \
 wget https://github.com/intel/compute-runtime/releases/download/25.40.35563.4/libze-intel-gpu1_25.40.35563.4-0_amd64.deb  && \
 dpkg -i *.deb || true && \
 apt-get update && \
 apt-get install -f -y && \  # Fix dependencies
 dpkg -i *.deb && \          # Try again after fixing
 rm *.deb

    
# Install Ollama Portable Zip https://github.com/intel/ipex-llm/releases/download/v2.2.0/llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=ollama-ipex-llm-2.2.0-ubuntu.tgz
RUN cd / && \
  wget https://github.com/intel/ipex-llm/releases/download/v2.2.0/${IPEXLLM_PORTABLE_ZIP_FILENAME} && \
  tar xvf ${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C /

ENV OLLAMA_HOST=0.0.0.0:11434

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
