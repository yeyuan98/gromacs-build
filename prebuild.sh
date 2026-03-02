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
