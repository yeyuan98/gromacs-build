#!/bin/bash
set -e

echo "==================================="
echo "BUILD: Starting build process"
echo "==================================="

# Create build directory
mkdir -p build
cd build

# Configure with CMake
echo "Configuring with CMake..."
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=install

# Build
echo "Building..."
make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Test the binary
echo "Testing the built binary..."
./hello

echo "Build process complete"
echo ""
