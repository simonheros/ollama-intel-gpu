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
        hwloc \
        wget \
        curl \
        vim \
        less \
        jq \
        python3-pip \
        python3-setuptools && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Install Intel GPU runtime components
# ------------------------------------------------------------
RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ocl-icd-libopencl1 \
        intel-opencl-icd \
        intel-level-zero-gpu && \
    rm -rf /var/lib/apt/lists/* || echo "Some packages may not be available, continuing..."

# ------------------------------------------------------------
# Add GPU diagnostics script
# ------------------------------------------------------------
RUN tee /usr/local/bin/check-gpu >/dev/null <<'EOF'
#!/bin/bash
set -e
echo "=== Intel GPU Diagnostic Summary ==="

echo
echo "-> PCI Devices:"
lspci | grep -i 'vga\|3d\|display' || echo "No GPU devices found via lspci"

echo
echo "-> /dev/dri contents:"
ls -l /dev/dri 2>/dev/null || echo "/dev/dri not accessible"

echo
echo "-> oneAPI Level Zero devices:"
if command -v sycl-ls &>/dev/null; then
    sycl-ls 2>/dev/null || echo "sycl-ls found but execution failed"
elif command -v ze_device_info &>/dev/null; then
    ze_device_info 2>/dev/null || echo "ze_device_info found but execution failed"
else
    echo "Level Zero tools not available"
fi

echo
echo "-> OpenCL (clinfo):"
if command -v clinfo &>/dev/null; then
    clinfo 2>/dev/null | grep -E "Platform Name|Device Name|Device Type" | head -10 || echo "clinfo executed but no devices found"
else
    echo "clinfo not installed"
fi

echo
echo "-> PyTorch XPU detection:"
python3 - <<'PYCODE'
try:
    import torch
    print(f"PyTorch version: {torch.__version__}")
    if hasattr(torch, "xpu") and callable(getattr(torch.xpu, "device_count", None)):
        count = torch.xpu.device_count()
        print(f"XPU device count: {count}")
        for i in range(count):
            print(f" - Device {i}: {torch.xpu.get_device_name(i)}")
    else:
        print("XPU not available in this PyTorch build")
        
    if torch.cuda.is_available():
        print(f"CUDA device count: {torch.cuda.device_count()}")
    else:
        print("CUDA not available")
except Exception as e:
    print(f"Error checking PyTorch devices: {e}")
PYCODE
EOF

RUN chmod +x /usr/local/bin/check-gpu

# ------------------------------------------------------------
# Install Python dependen
