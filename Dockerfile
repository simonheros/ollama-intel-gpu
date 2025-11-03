# ============================================================
# Base image: Intel oneAPI 2025.3.0 for Ubuntu 22.04
# ============================================================
FROM intel/oneapi-basekit:2025.3.0-0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Install GPU diagnostics and system utilities
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        pciutils \
        usbutils \
        clinfo \
        vainfo \
        mesa-utils \
        intel-opencl-icd \
        intel-level-zero-gpu \
        hwloc \
        wget \
        curl \
        vim \
        less \
        jq \
        python3-pip && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Add GPU diagnostics script
# ------------------------------------------------------------
RUN tee /usr/local/bin/check-gpu >/dev/null <<'EOF'
#!/bin/bash
set -eux
echo "=== Intel GPU Diagnostic Summary ==="

echo
echo "-> PCI Devices:"
lspci | grep -i 'vga\|3d\|display' || true

echo
echo "-> /dev/dri contents:"
ls -l /dev/dri || true

echo
echo "-> oneAPI Level Zero devices:"
if command -v ze_device_info &>/dev/null; then
    ze_device_info || echo "ze_device_info not available."
else
    echo "ze_device_info not installed."
fi

echo
echo "-> OpenCL (clinfo):"
clinfo | grep -E "Platform Name|Device Name" || true

echo
echo "-> PyTorch XPU detection:"
python3 - <<'PYCODE'
import torch
if hasattr(torch, "xpu"):
    print("XPU device count:", torch.xpu.device_count())
    for i in range(torch.xpu.device_count()):
        print(" -", torch.xpu.get_device_name(i))
else:
    print("No XPU backend in torch.")
PYCODE
EOF

RUN chmod +x /usr/local/bin/check-gpu

# ------------------------------------------------------------
# Install Python dependencies for Intel PyTorch + OpenVINO
# ------------------------------------------------------------
RUN set -eux; \
    pip install --no-cache-dir \
        torch==2.3.1+cpu \
        torchvision==0.18.1+cpu \
        torchaudio==2.3.1+cpu \
        --index-url https://download.pytorch.org/whl/cpu && \
    pip install --no-cache-dir \
        intel-extension-for-pytorch==2.3.100 \
        ipex-llm==2.2.0 \
        openvino==2024.3.0 \
        openvino-dev==2024.3.0 \
        numpy==1.26.4 \
        requests==2.32.3 && \
    rm -rf /root/.cache/pip

# ------------------------------------------------------------
# Environment configuration for oneAPI / IPEX / OpenVINO
# ------------------------------------------------------------
ENV SYCL_DEVICE_FILTER=level_zero:gpu \
    ONEAPI_DEVICE_SELECTOR=level_zero:gpu \
    ZES_ENABLE_SYSMAN=1 \
    SYCL_PI_LEVEL_ZERO_USE_MULTI_DEVICE_CONTEXT=1 \
    SYCL_QUEUE_THREAD_POOL_SIZE=16 \
    IPEX_LLM_GPU_RUNTIME=level_zero \
    TORCH_DEVICE=xpu \
    OMP_NUM_THREADS=16 \
    MKL_NUM_THREADS=16 \
    KMP_AFFINITY="granularity=fine,compact,1,0" \
    OPENVINO_DEVICE=GPU \
    OPENVINO_LOG_LEVEL=INFO

# ------------------------------------------------------------
# Default command
# ------------------------------------------------------------
CMD ["/bin/bash"]
