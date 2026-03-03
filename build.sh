#!/bin/bash
set -e

echo "==================================="
echo "BUILD: Building GROMACS 2026.0"
echo "==================================="

# Get source directory (where CMakeLists.txt is located)
SOURCE_DIR=$(pwd)
BUILD_DIR="$SOURCE_DIR/build"
INSTALL_PREFIX="$SOURCE_DIR/install"

echo "Source directory: $SOURCE_DIR"
echo "Build directory: $BUILD_DIR"
echo "Install prefix: $INSTALL_PREFIX"
echo ""

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with CMake
echo "Configuring GROMACS with CMake..."
echo ""

cmake "$SOURCE_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DGMX_BUILD_OWN_FFTW=ON \
    -DGMX_GPU=CUDA \
    -DGMX_MPI=ON \
    -DGMX_DOUBLE=OFF \
    -DGMX_SIMD=AVX2_256 \
    -DBUILD_SHARED_LIBS=OFF \
    -DGMXAPI=OFF \
    -DGMX_INSTALL_NBLIB_API=OFF \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
    -DCMAKE_CUDA_ARCHITECTURES="80;86;89;90" \
    -DREGRESSIONTEST_DOWNLOAD=OFF

echo ""
echo "CMake configuration complete"
echo ""

# Build with parallel make
NUM_JOBS=$(nproc)
echo "Building GROMACS with $NUM_JOBS parallel jobs..."
echo ""

make -j"$NUM_JOBS"

echo ""
echo "Build complete"
echo ""

# Install (no sudo needed, relative path)
echo "Installing GROMACS to $INSTALL_PREFIX..."
make install

echo ""
echo "Installation complete"
echo ""

# Verify installation
# When MPI is enabled, binary is named gmx_mpi instead of gmx
GMX_BIN="gmx_mpi"
if [ ! -f "$INSTALL_PREFIX/bin/$GMX_BIN" ]; then
    echo "::error::GROMACS binary not found at $INSTALL_PREFIX/bin/$GMX_BIN"
    exit 1
fi

echo "Verifying installation:"
ls -lh "$INSTALL_PREFIX/bin/$GMX_BIN"
echo ""

# Display build summary
echo "==================================="
echo "GROMACS Build Summary:"
echo "  Version: 2026.0"
echo "  Build type: Release"
echo "  Libraries: Static"
echo "  SIMD: AVX2_256"
echo "  Threading: Thread-MPI + MPI"
echo "  GPU: CUDA (80;86;89;90)"
echo "  Precision: Single/Mixed"
echo "  Install path: $INSTALL_PREFIX"
echo "==================================="
echo ""
