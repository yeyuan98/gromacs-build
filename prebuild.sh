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

echo ""
echo "System Information:"
echo "  CPU cores: $(nproc)"
echo "  Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "  Disk space: $(df -h . | tail -1 | awk '{print $4}') available"
echo ""

# --- Phase 1: Validate prerequisites ---
CONFIG_FILE="target-cmake.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "::error::$CONFIG_FILE not found"
    exit 1
fi

# --- Phase 2: Install jq if needed ---
if ! command -v jq &>/dev/null; then
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq jq
    else
        echo "::error::jq not found and no apt-get available"
        exit 1
    fi
fi

# --- Phase 3: Validate JSON schema ---
echo "Validating $CONFIG_FILE..."

REQUIRED_FIELDS=("target_name" "tarball_url" "gromacs_version" "runner" "platform" "cmake" "runtime_deps")
for field in "${REQUIRED_FIELDS[@]}"; do
    val=$(jq -r ".$field" "$CONFIG_FILE")
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "::error::Missing required field in $CONFIG_FILE: $field"
        exit 1
    fi
done

CMAKE_REQUIRED=("CMAKE_BUILD_TYPE" "GMX_BUILD_OWN_FFTW" "GMX_GPU" "GMX_MPI" "GMX_DOUBLE" "GMX_SIMD")
for field in "${CMAKE_REQUIRED[@]}"; do
    val=$(jq -r ".cmake.$field" "$CONFIG_FILE")
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "::error::Missing required cmake field in $CONFIG_FILE: $field"
        exit 1
    fi
done

GMX_GPU_VAL=$(jq -r '.cmake.GMX_GPU' "$CONFIG_FILE")
if [ "$GMX_GPU_VAL" = "CUDA" ]; then
    CUDA_FIELDS=("cuda_version" "cuda_repo_distro" "cuda_keyring_version")
    for field in "${CUDA_FIELDS[@]}"; do
        val=$(jq -r ".$field" "$CONFIG_FILE")
        if [ -z "$val" ] || [ "$val" = "null" ]; then
            echo "::error::Missing CUDA-specific field in $CONFIG_FILE: $field"
            exit 1
        fi
    done
    val=$(jq -r '.cmake.CMAKE_CUDA_ARCHITECTURES' "$CONFIG_FILE")
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "::error::Missing cmake field: CMAKE_CUDA_ARCHITECTURES"
        exit 1
    fi
fi

echo "Configuration validated"

# --- Phase 4: Generate build-config.sh ---
generate_build_config() {
    local config="$CONFIG_FILE"

    local version=$(jq -r '.gromacs_version' "$config")
    local cuda_ver=$(jq -r '.cuda_version' "$config")
    local platform=$(jq -r '.platform' "$config")
    local target_name=$(jq -r '.target_name' "$config")
    local build_type=$(jq -r '.cmake.CMAKE_BUILD_TYPE' "$config")
    local gmx_simd=$(jq -r '.cmake.GMX_SIMD' "$config")
    local gmx_gpu=$(jq -r '.cmake.GMX_GPU' "$config")
    local cuda_arch=$(jq -r '.cmake.CMAKE_CUDA_ARCHITECTURES' "$config")
    local runtime_deps=$(jq -r '.runtime_deps | join(" ")' "$config")

    local gmx_mpi=$(jq -r '.cmake.GMX_MPI' "$config")
    local gmx_bin threading
    case "$gmx_mpi" in
        ON)  gmx_bin="gmx_mpi"; threading="External MPI" ;;
        OFF) gmx_bin="gmx";     threading="Thread-MPI" ;;
        *)   echo "::error::GMX_MPI must be ON or OFF, got: $gmx_mpi"; exit 1 ;;
    esac

    local gmx_double=$(jq -r '.cmake.GMX_DOUBLE' "$config")
    local precision
    case "$gmx_double" in
        ON)  precision="Double" ;;
        OFF) precision="Single/Mixed" ;;
        *)   echo "::error::GMX_DOUBLE must be ON or OFF, got: $gmx_double"; exit 1 ;;
    esac

    local suffix=$(jq -r '.cmake.CMAKE_FIND_LIBRARY_SUFFIXES' "$config")
    local lib_type
    case "$suffix" in
        .a)  lib_type="Static" ;;
        .so) lib_type="Shared" ;;
        *)   lib_type="Mixed ($suffix)" ;;
    esac

    local gpu_label
    if [ "$gmx_gpu" = "OFF" ]; then
        gpu_label="None (CPU only)"
    elif [ -n "$cuda_arch" ] && [ "$cuda_arch" != "null" ]; then
        gpu_label="$gmx_gpu ($cuda_arch)"
    else
        gpu_label="$gmx_gpu"
    fi

    local cmake_flags_str
    cmake_flags_str=$(jq -r '.cmake | to_entries[] | "-D\(.key)=\(.value)"' "$config" | paste -sd ' ')

    cat > "build-config.sh" << CONF_EOF
#!/bin/bash
GMX_VERSION="$version"
GMX_BIN="$gmx_bin"
CUDA_VERSION="$cuda_ver"
PLATFORM="$platform"
TARGET_NAME="$target_name"
BUILD_TYPE="$build_type"
GMX_SIMD="$gmx_simd"
GMX_GPU="$gmx_gpu"
CUDA_ARCH="$cuda_arch"
THREADING="$threading"
PRECISION="$precision"
LIB_TYPE="$lib_type"
GPU_LABEL="$gpu_label"
RUNTIME_DEPS="$runtime_deps"
ARTIFACT_NAME="built_artefact.tar.bz2"
CMAKE_FLAGS=($cmake_flags_str)
SOURCE_DIR="\$(pwd)"
BUILD_DIR="\$SOURCE_DIR/build"
INSTALL_DIR="\$SOURCE_DIR/install"
CONF_EOF

    chmod +x "build-config.sh"
}

echo "Generating build configuration..."
generate_build_config
echo "build-config.sh generated"

# --- Phase 5: Source build-config.sh ---
source ./build-config.sh

echo ""
echo "Build Configuration:"
echo "  Target: $TARGET_NAME"
echo "  GROMACS: $GMX_VERSION"
echo "  Binary: $GMX_BIN"
echo "  SIMD: $GMX_SIMD"
echo "  Threading: $THREADING"
echo "  GPU: $GPU_LABEL"
echo "  Precision: $PRECISION"
echo "  Platform: $PLATFORM"
echo ""

# --- Phase 6: Install build dependencies ---
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

# --- Phase 7: Install CUDA (conditional) ---
if [ "$GMX_GPU" = "CUDA" ]; then
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
    echo "CUDA installation skipped (GMX_GPU=$GMX_GPU)"
fi

# --- Phase 8: Verify toolchain ---
echo ""
echo "Verifying toolchain versions:"
echo "  CMake: $(cmake --version | head -1 | cut -d' ' -f3)"
echo "  GCC: $(gcc --version | head -1)"
echo "  G++: $(g++ --version | head -1)"
echo "  Make: $(make --version | head -1)"

export CC=gcc
export CXX=g++

echo ""
echo "Prebuild environment setup complete"
echo ""
