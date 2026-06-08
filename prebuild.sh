#!/bin/bash
set -e

VARIANT_INDEX="${1:?Usage: prebuild.sh <variant-index>}"

echo "==================================="
echo "PREBUILD: Setting up GROMACS build environment (variant $VARIANT_INDEX)"
echo "==================================="

if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Detected OS: $PRETTY_NAME"
fi

echo ""
echo "System Information:"
echo "  CPU cores: $(nproc)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Disk space: $(df -h . | tail -1 | awk '{print $4}') available"
echo ""

CONFIG_FILE="target-cmake.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "::error::$CONFIG_FILE not found"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq jq
    else
        echo "::error::jq not found and no apt-get available"
        exit 1
    fi
fi

echo "Validating $CONFIG_FILE..."

REQUIRED_FIELDS=("gromacs_version" "tarball_url" "runner" "platform" "cmake_base" "runtime_deps" "variants")
for field in "${REQUIRED_FIELDS[@]}"; do
    val=$(jq -r ".$field" "$CONFIG_FILE")
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "::error::Missing required field in $CONFIG_FILE: $field"
        exit 1
    fi
done

VARIANT_COUNT=$(jq '.variants | length' "$CONFIG_FILE")
if [ "$VARIANT_INDEX" -ge "$VARIANT_COUNT" ] || [ "$VARIANT_INDEX" -lt 0 ]; then
    echo "::error::Variant index $VARIANT_INDEX out of range (0-$((VARIANT_COUNT-1)))"
    exit 1
fi

GMX_GPU_VARIANT=$(jq -r ".variants[$VARIANT_INDEX].GMX_GPU // empty" "$CONFIG_FILE")
GMX_GPU_BASE=$(jq -r '.cmake_base.GMX_GPU' "$CONFIG_FILE")
GMX_GPU_EFFECTIVE="${GMX_GPU_VARIANT:-$GMX_GPU_BASE}"

if [ "$GMX_GPU_EFFECTIVE" = "CUDA" ]; then
    CUDA_FIELDS=("cuda_version" "cuda_repo_distro" "cuda_keyring_version")
    for field in "${CUDA_FIELDS[@]}"; do
        val=$(jq -r ".$field" "$CONFIG_FILE")
        if [ -z "$val" ] || [ "$val" = "null" ]; then
            echo "::error::Missing CUDA-specific field in $CONFIG_FILE: $field"
            exit 1
        fi
    done
    val=$(jq -r '.cmake_base.CMAKE_CUDA_ARCHITECTURES' "$CONFIG_FILE")
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "::error::Missing cmake_base field: CMAKE_CUDA_ARCHITECTURES"
        exit 1
    fi
fi

echo "Configuration validated"

echo "Generating build configuration for variant $VARIANT_INDEX..."

version=$(jq -r '.gromacs_version' "$CONFIG_FILE")
platform=$(jq -r '.platform' "$CONFIG_FILE")
build_type=$(jq -r '.cmake_base.CMAKE_BUILD_TYPE' "$CONFIG_FILE")
runtime_deps=$(jq -r '.runtime_deps | join(" ")' "$CONFIG_FILE")

gmx_simd=$(jq -r ".variants[$VARIANT_INDEX].GMX_SIMD" "$CONFIG_FILE")
gmx_double=$(jq -r ".variants[$VARIANT_INDEX].GMX_DOUBLE" "$CONFIG_FILE")
cuda_ver=$(jq -r '.cuda_version' "$CONFIG_FILE")

case "$gmx_double" in
    ON)  precision="double" ;;
    OFF) precision="float" ;;
    *)   echo "::error::GMX_DOUBLE must be ON or OFF, got: $gmx_double"; exit 1 ;;
esac

gmx_mpi=$(jq -r --argjson idx "$VARIANT_INDEX" '
    (.cmake_base * .variants[$idx]).GMX_MPI // "OFF"
' "$CONFIG_FILE")
case "$gmx_mpi" in
    ON)  threading="External MPI" ;;
    OFF) threading="Thread-MPI" ;;
    *)   echo "::error::GMX_MPI must be ON or OFF, got: $gmx_mpi"; exit 1 ;;
esac

if [ "$threading" = "External MPI" ]; then
    artifact_name="${gmx_simd}-${precision}-mpi.tar.bz2"
else
    artifact_name="${gmx_simd}-${precision}.tar.bz2"
fi

if [ "$GMX_GPU_EFFECTIVE" = "CUDA" ]; then
    cuda_arch=$(jq -r '.cmake_base.CMAKE_CUDA_ARCHITECTURES' "$CONFIG_FILE")
    gpu_label="CUDA ($cuda_arch)"
else
    gpu_label="CPU only"
fi

suffix=$(jq -r '.cmake_base.CMAKE_FIND_LIBRARY_SUFFIXES // ".a"' "$CONFIG_FILE")
case "$suffix" in
    .a)  lib_type="Static" ;;
    .so) lib_type="Shared" ;;
    *)   lib_type="Mixed ($suffix)" ;;
esac

if [ "$threading" = "External MPI" ]; then
    runtime_deps="$runtime_deps openmpi-bin libopenmpi-dev"
fi

cmake_flags_str=$(jq -r --argjson idx "$VARIANT_INDEX" '
    .cmake_base * .variants[$idx] | to_entries | sort_by(.key) |
    .[] | "-D\(.key)=\(.value)" | @sh
' "$CONFIG_FILE" | paste -sd ' ')

if [ "$threading" = "External MPI" ]; then
    target_name="GROMACS-${version}-${gmx_simd}-${precision}-mpi"
else
    target_name="GROMACS-${version}-${gmx_simd}-${precision}"
fi

cat > "build-config-${VARIANT_INDEX}.sh" << CONF_EOF
#!/bin/bash
GMX_VERSION="$version"
GMX_BIN="DETECTED_AFTER_INSTALL"
CUDA_VERSION="$cuda_ver"
PLATFORM="$platform"
TARGET_NAME="$target_name"
BUILD_TYPE="$build_type"
GMX_SIMD="$gmx_simd"
GMX_DOUBLE="$gmx_double"
GMX_GPU="$GMX_GPU_EFFECTIVE"
THREADING="$threading"
PRECISION="$precision"
LIB_TYPE="$lib_type"
GPU_LABEL="$gpu_label"
RUNTIME_DEPS="$runtime_deps"
ARTIFACT_NAME="$artifact_name"
VARIANT_INDEX="$VARIANT_INDEX"
CMAKE_FLAGS=($cmake_flags_str)
SOURCE_DIR="\$(pwd)"
BUILD_DIR="\$SOURCE_DIR/build-${VARIANT_INDEX}"
INSTALL_DIR="\$SOURCE_DIR/install-${VARIANT_INDEX}"
CONF_EOF

chmod +x "build-config-${VARIANT_INDEX}.sh"

source "./build-config-${VARIANT_INDEX}.sh"

echo ""
echo "Build Configuration (variant $VARIANT_INDEX):"
echo "  Target: $TARGET_NAME"
echo "  GROMACS: $GMX_VERSION"
echo "  Binary: $GMX_BIN"
echo "  SIMD: $GMX_SIMD"
echo "  Precision: $PRECISION"
echo "  Threading: $THREADING"
echo "  GPU: $GPU_LABEL"
echo "  Platform: $PLATFORM"
echo "  Artifact: $ARTIFACT_NAME"
echo ""

if command -v apt-get &>/dev/null; then
    echo "Installing build dependencies..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        build-essential \
        cmake \
        git \
        zlib1g-dev \
        wget \
        pkg-config

    if [ "$THREADING" = "External MPI" ]; then
        echo "Installing MPI libraries (GMX_MPI=ON)..."
        sudo apt-get install -y -qq openmpi-bin openmpi-common libopenmpi-dev
    fi
else
    echo "::error::This build script only supports apt-get (Ubuntu/Debian)"
    exit 1
fi

if [ "$GMX_GPU_EFFECTIVE" = "CUDA" ]; then
    echo "Installing NVIDIA CUDA Toolkit $CUDA_VERSION..."

    local_cuda_repo_distro=$(jq -r '.cuda_repo_distro' "$CONFIG_FILE")
    local_cuda_keyring_ver=$(jq -r '.cuda_keyring_version' "$CONFIG_FILE")
    local_cuda_pkg_ver=$(echo "$CUDA_VERSION" | tr '.' '-')

    wget -q "https://developer.download.nvidia.com/compute/cuda/repos/${local_cuda_repo_distro}/x86_64/cuda-keyring_${local_cuda_keyring_ver}_all.deb"
    sudo dpkg -i "cuda-keyring_${local_cuda_keyring_ver}_all.deb"
    sudo apt-get update -qq
    sudo apt-get install -y -qq "cuda-toolkit-${local_cuda_pkg_ver}"

    export PATH=/usr/local/cuda/bin:$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

    echo "Verifying CUDA installation..."
    nvcc --version
else
    echo "CUDA installation skipped (GMX_GPU=$GMX_GPU_EFFECTIVE)"
fi

echo ""
echo "Verifying toolchain versions:"
echo "  CMake: $(cmake --version | head -1 | cut -d' ' -f3)"
echo "  GCC: $(gcc --version | head -1)"
echo "  G++: $(g++ --version | head -1)"
echo "  Make: $(make --version | head -1)"

export CC=gcc
export CXX=g++

echo ""
echo "Prebuild environment setup complete (variant $VARIANT_INDEX)"
echo ""
