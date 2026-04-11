#!/bin/bash
set -e

echo "==================================="
echo "PREBUILD: Setting up GROMACS build environment"
echo "==================================="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Detected OS: $PRETTY_NAME"
fi

# Display system information
echo ""
echo "System Information:"
echo "  CPU cores: $(nproc)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Disk space: $(df -h . | tail -1 | awk '{print $4}') available"
echo ""

# Install GROMACS build dependencies
if command -v apt-get &> /dev/null; then
    echo "Installing GROMACS build dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        cmake \
        git \
        zlib1g-dev \
        wget \
        pkg-config
else
    echo "::error::This build script only supports apt-get (Ubuntu/Debian)"
    exit 1
fi

# Install NVIDIA CUDA Toolkit 13.0
echo "Installing NVIDIA CUDA Toolkit 13.0..."
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update
sudo apt-get install -y cuda-toolkit-13-0

# Set CUDA environment variables
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# Verify CUDA installation
echo "Verifying CUDA installation..."
nvcc --version

# Verify toolchain versions
echo ""
echo "Verifying toolchain versions:"
echo "  CMake: $(cmake --version | head -1 | cut -d' ' -f3)"
echo "  GCC: $(gcc --version | head -1)"
echo "  G++: $(g++ --version | head -1)"
echo "  Make: $(make --version | head -1)"

# Set environment variables
export CC=gcc
export CXX=g++

echo ""
echo "Prebuild environment setup complete"
echo ""
