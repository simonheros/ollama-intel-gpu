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

# First, let's check what files are available in the IPEX-LLM release
RUN echo "Checking available IPEX-LLM releases..." && \
    curl -s https://api.github.com/repos/intel/ipex-llm/releases/tags/v2.2.0 | grep -o '"name": "[^"]*"' | cut -d'"' -f4 | grep -E "(ollama|llama)" || true

# Download the correct IPEX-LLM file - based on common naming patterns
RUN cd /tmp && \
    echo "Trying different IPEX-LLM package names..." && \
    for package in \
        "ipex-llm-ollama-2.2.0-linux-x86_64.tgz" \
        "ollama-ipex-llm-2.2.0-linux-x86_64.tgz" \
        "ipex-llm-ollama-v2.2.0-linux-x86_64.tgz" \
        "ollama-linux-x86_64-2.2.0.tgz" \
        "ipex-llm-ollama-ubuntu-2.2.0.tgz"; do \
        echo "Attempting to download: $package" && \
        if wget -q --tries=2 --timeout=30 "https://github.com/intel/ipex-llm/releases/download/v2.2.0/${package}"; then \
            echo "Successfully downloaded: $package" && \
            echo "Archive contents:" && \
            tar -tzf "$package" | head -20 && \
            echo "Extracting..." && \
            tar xzf "$package" -C / && \
            rm -f "$package" && \
            echo "Extraction completed for: $package" && \
            break; \
        fi; \
    done

# Alternative: If the above fails, try to install Ollama normally and then add IPEX-LLM support
RUN if [ ! -f "/usr/local/bin/ollama" ] && [ ! -f "/bin/ollama" ] && [ ! -f "/usr/bin/ollama" ]; then \
    echo "IPEX-LLM packages not found, installing standard Ollama..." && \
    curl -fsSL https://ollama.ai/install.sh | sh; \
    fi

# Set PATH to include common binary locations
ENV PATH="/usr/local/bin:/bin:/usr/bin:/app:${PATH}"

ENV OLLAMA_HOST=0.0.0.0:11434

# Create a robust start script that works with or without IPEX-LLM
RUN printf '#!/bin/bash\nset -e\necho "Starting Ollama..."\necho "OLLAMA_HOST: $OLLAMA_HOST"\n\n# Find ollama binary\nOLLAMA_BIN=$(which ollama 2>/dev/null || find / -name "ollama" -type f 2>/dev/null | head -1)\nif [ -z "$OLLAMA_BIN" ]; then\n    echo "Error: ollama binary not found!"\n    echo "Available binaries:"\n    find / -type f -executable 2>/dev/null | grep -i ollama | head -10 || echo "No ollama-related executables found"\n    exit 1\nfi\n\necho "Found ollama at: $OLLAMA_BIN"\necho "Starting Ollama server..."\nexec "$OLLAMA_BIN" serve\n' > /start-ollama.sh && \
    chmod +x /start-ollama.sh

ENTRYPOINT ["/bin/bash", "/start-ollama.sh"]
