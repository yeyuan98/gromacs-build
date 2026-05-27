#!/bin/bash
set -e

source "$(dirname "$0")/build-config.sh"

echo "==================================="
echo "BUILD: Building GROMACS $GMX_VERSION"
echo "==================================="

echo "Source directory: $SOURCE_DIR"
echo "Build directory: $BUILD_DIR"
echo "Install prefix: $INSTALL_DIR"
echo ""

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "Configuring GROMACS with CMake..."
echo ""

cmake "$SOURCE_DIR" "${CMAKE_FLAGS[@]}" -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR"

echo ""
echo "CMake configuration complete"
echo ""

NUM_JOBS=$(nproc)
echo "Building GROMACS with $NUM_JOBS parallel jobs..."
echo ""

make -j"$NUM_JOBS"

echo ""
echo "Build complete"
echo ""

echo "Installing GROMACS to $INSTALL_DIR..."
make install

echo ""
echo "Installation complete"
echo ""

if [ ! -f "$INSTALL_DIR/bin/$GMX_BIN" ]; then
    echo "::error::GROMACS binary not found at $INSTALL_DIR/bin/$GMX_BIN"
    exit 1
fi

echo "Verifying installation:"
ls -lh "$INSTALL_DIR/bin/$GMX_BIN"
echo ""

echo "==================================="
echo "GROMACS Build Summary:"
echo "  Version: $GMX_VERSION"
echo "  Build type: $BUILD_TYPE"
echo "  Libraries: $LIB_TYPE"
echo "  SIMD: $GMX_SIMD"
echo "  Threading: $THREADING"
echo "  GPU: $GPU_LABEL"
echo "  Precision: $PRECISION"
echo "  Install path: $INSTALL_DIR"
echo "==================================="
echo ""
