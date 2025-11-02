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

# Try multiple possible IPEX-LLM filenames
RUN cd /tmp && \
    for filename in \
        "ollama-ipex-llm-2.2.0-ubuntu.tgz" \
        "ollama-ipex-llm-cpu-2.2.0-ubuntu.tgz" \
        "llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz"; do \
        echo "Trying to download: $filename" && \
        if wget -q --tries=2 --timeout=30 "https://github.com/intel/ipex-llm/releases/download/v2.2.0/${filename}"; then \
            echo "Successfully downloaded: $filename" && \
            tar xvf "${filename}" --strip-components=1 -C / && \
            rm -f "${filename}" && \
            echo "Successfully extracted: $filename" && \
            break; \
        else \
            echo "Failed to download: $filename" && \
            rm -f "${filename}"; \
        fi; \
    done

ENV OLLAMA_HOST=0.0.0.0:11434

# Create start script - simple and reliable approach
RUN printf '#!/bin/bash\necho "Starting Ollama with IPEX-LLM..."\necho "OLLAMA_HOST: $OLLAMA_HOST"\nexec ollama serve\n' > /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
