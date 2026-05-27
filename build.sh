#!/bin/bash
set -e

VARIANT_INDEX="${1:?Usage: build.sh <variant-index>}"

source "$(dirname "$0")/build-config-${VARIANT_INDEX}.sh"

echo "==================================="
echo "BUILD: Building GROMACS $GMX_VERSION (variant $VARIANT_INDEX)"
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

GMX_BIN=$(find "$INSTALL_DIR/bin" -maxdepth 1 -name 'gmx*' -type f -executable | head -1 | xargs basename)

if [ -z "$GMX_BIN" ]; then
    echo "::error::No GROMACS binary (gmx*) found in $INSTALL_DIR/bin"
    ls -la "$INSTALL_DIR/bin/"
    exit 1
fi

sed -i "s|^GMX_BIN=.*|GMX_BIN=\"$GMX_BIN\"|" "$SOURCE_DIR/build-config-${VARIANT_INDEX}.sh"

echo "Detected GROMACS binary: $GMX_BIN"
ls -lh "$INSTALL_DIR/bin/$GMX_BIN"
echo ""

echo "==================================="
echo "GROMACS Build Summary (variant $VARIANT_INDEX):"
echo "  Version: $GMX_VERSION"
echo "  Build type: $BUILD_TYPE"
echo "  SIMD: $GMX_SIMD"
echo "  Precision: $PRECISION"
echo "  Threading: $THREADING"
echo "  GPU: $GPU_LABEL"
echo "  Libraries: $LIB_TYPE"
echo "  Install path: $INSTALL_DIR"
echo "==================================="
echo ""
