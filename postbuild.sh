#!/bin/bash
set -e

echo "==================================="
echo "POSTBUILD: Creating GROMACS artifact"
echo "==================================="

# Get source directory
SOURCE_DIR=$(pwd)
INSTALL_DIR="$SOURCE_DIR/install"

# Verify installation directory exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo "::error::Installation directory not found: $INSTALL_DIR"
    exit 1
fi

# Verify GROMACS binary exists
# When MPI is enabled, binary is named gmx_mpi instead of gmx
if [ ! -f "$INSTALL_DIR/bin/gmx_mpi" ]; then
    echo "::error::GROMACS binary not found at $INSTALL_DIR/bin/gmx_mpi"
    exit 1
fi

echo "GROMACS installation found at: $INSTALL_DIR"
echo ""

# Display installation contents
echo "Installation contents:"
echo "  Binaries: $(ls $INSTALL_DIR/bin/ | wc -l) files"
echo "  Libraries: $(ls $INSTALL_DIR/lib/ 2>/dev/null | wc -l) files"
echo "  Headers: $(find $INSTALL_DIR/include -type f | wc -l) files"
echo "  Share: $(find $INSTALL_DIR/share -type f | wc -l) files"
echo ""

# Create README for the artifact
cat > "$INSTALL_DIR/README.txt" << 'EOF'
GROMACS 2026.0 - CUDA GPU Build
===============================

Build Configuration:
  Version:        2026.0
  Build type:     Release
  Libraries:      Static
  SIMD:           AVX2_256
  Threading:      Thread-MPI + MPI
  GPU:            CUDA (80;86;89;90)
  Precision:      Single/Mixed
  Platform:       Ubuntu 24.04 AMD64
  CUDA:           12.6 Toolkit

Installation:
  tar -xjf built_artefact.tar.bz2

Usage:
  source bin/GMXRC
  gmx_mpi --version

Supported GPUs:
  Consumer: RTX 30 series (3060-3090 Ti)
             RTX 40 series (4050-4090)
  Datacenter: A100, A10, A30, A40 (Ampere)
              H100, H200 (Hopper)
              L40, L40S (Ada)
  Compute Capabilities: 8.0, 8.6, 8.9, 9.0

Requirements:
  - NVIDIA GPU with Compute Capability 8.0+
  - CUDA 12.1+ compatible driver
  - RTX 50 series NOT supported (requires CUDA 13.0+)

Multi-GPU:
  - MPI enabled for multi-GPU simulations
  - Use mpirun/mpiexec for parallel execution
  - GPU-aware MPI auto-detected at compile time

Troubleshooting:
  If GPU-aware MPI fails to auto-detect:
    export GMX_FORCE_GPU_AWARE_MPI=1
  (Rare case, most systems work automatically)

For more information:
  https://manual.gromacs.org/current/
  https://www.gromacs.org/

Contents:
  bin/        - Executables (gmx, GMXRC, completion scripts)
  lib/        - Static libraries and CMake config
  include/    - Header files for development
  share/      - Force fields, templates, man pages, CMake config
EOF

# Create setup helper script
cat > "$INSTALL_DIR/setup_gromacs.sh" << 'EOF'
#!/bin/bash
# GROMACS environment setup script
GMX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$GMX_DIR/bin/GMXRC"
export PATH="$GMX_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$GMX_DIR/lib:$LD_LIBRARY_PATH"
echo "GROMACS environment set up"
echo "GMX bin: $GMX_DIR/bin"
echo "GMX version: $(gmx_mpi --version 2>&1 | head -1)"
EOF
chmod +x "$INSTALL_DIR/setup_gromacs.sh"

# Create the artifact
echo "Creating artifact tarball..."
WORKING_DIR=$(pwd)
cd "$INSTALL_DIR"
tar -cjf "$WORKING_DIR/built_artefact.tar.bz2" .
cd "$WORKING_DIR"

# Verify artifact was created
if [ ! -f "built_artefact.tar.bz2" ]; then
    echo "::error::built_artefact.tar.bz2 was not created"
    exit 1
fi

# Get artifact size
ARTIFACT_SIZE=$(stat -c%s "built_artefact.tar.bz2" 2>/dev/null || stat -f%z "built_artefact.tar.bz2" 2>/dev/null || echo "unknown")
ARTIFACT_SIZE_HR=$(du -h "built_artefact.tar.bz2" | cut -f1)

echo ""
echo "Postbuild complete"
echo "Artifact created: built_artefact.tar.bz2 ($ARTIFACT_SIZE_HR)"
echo ""

# Show artifact contents (first 20 files)
echo "Artifact contents (first 20 files):"
tar -tjf built_artefact.tar.bz2 | head -20
echo "..."
echo ""

# Verify artifact integrity
echo "Verifying artifact integrity..."
if tar -tjf built_artefact.tar.bz2 | grep -q "bin/gmx_mpi"; then
    echo "✓ GROMACS binary found in artifact"
else
    echo "::error::GROMACS binary not found in artifact"
    exit 1
fi

if tar -tjf built_artefact.tar.bz2 | grep -q "bin/GMXRC"; then
    echo "✓ GMXRC setup script found in artifact"
else
    echo "::error::GMXRC not found in artifact"
    exit 1
fi

if tar -tjf built_artefact.tar.bz2 | grep -q "share/gromacs/top/"; then
    echo "✓ Force field files found in artifact"
else
    echo "::error::Force field files not found in artifact"
    exit 1
fi

echo ""
echo "==================================="
echo "Artifact verification complete"
echo "==================================="
echo ""
