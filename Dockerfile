# -----------------------------------------------------------------------------
# 3. Install Intel GPU Runtime (with repo + fallback)
# -----------------------------------------------------------------------------
RUN set -eux; \
    # Add Intel GPG key and APT repository (use Jammy repo for 24.04 compatibility)
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
        gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg; \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] \
        https://repositories.intel.com/graphics/ubuntu jammy arc" \
        > /etc/apt/sources.list.d/intel-graphics.list; \
    \
    apt-get update || true; \
    if ! apt-get install -y --no-install-recommends \
        intel-opencl-icd \
        intel-level-zero-gpu \
        level-zero \
        intel-igc-core \
        intel-igc-opencl \
        libigdgmm12 \
        intel-ocloc; then \
        echo "⚠️ Intel APT install failed — falling back to manual GPU driver installation."; \
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
        apt-get install -fy; \
        dpkg -i *.deb; \
        rm -rf /tmp/gpu; \
    fi; \
    rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 4. Install IPEX-LLM Ollama portable package (corrected file name)
# -----------------------------------------------------------------------------
ARG IPEXLLM_PORTABLE_ZIP_FILENAME=llama-cpp-ipex-llm-2.2.0-ubuntu-core.tgz

RUN cd / && \
    wget -q https://github.com/intel/ipex-llm/releases/download/v2.2.0/${IPEXLLM_PORTABLE_ZIP_FILENAME} || \
      (echo "❌ Failed to download ${IPEXLLM_PORTABLE_ZIP_FILENAME}"; exit 1); \
    tar xvf ${IPEXLLM_PORTABLE_ZIP_FILENAME} --strip-components=1 -C / && \
    rm ${IPEXLLM_PORTABLE_ZIP_FILENAME}
