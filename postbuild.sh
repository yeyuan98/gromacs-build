#!/bin/bash
set -e

source "$(dirname "$0")/build-config.sh"

echo "==================================="
echo "POSTBUILD: Creating GROMACS artifact"
echo "==================================="

# Verify installation directory exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo "::error::Installation directory not found: $INSTALL_DIR"
    exit 1
fi

# Verify GROMACS binary exists
if [ ! -f "$INSTALL_DIR/bin/$GMX_BIN" ]; then
    echo "::error::GROMACS binary not found at $INSTALL_DIR/bin/$GMX_BIN"
    exit 1
fi

echo "GROMACS installation found at: $INSTALL_DIR"
echo ""

# Check dynamic dependencies (informational only)
echo "Dynamic library dependencies:"
ldd "$INSTALL_DIR/bin/$GMX_BIN" || true
echo ""

# Display installation contents
echo "Installation contents:"
echo "  Binaries: $(ls "$INSTALL_DIR/bin/" | wc -l) files"
if [ -d "$INSTALL_DIR/lib" ] && [ "$(ls -A "$INSTALL_DIR/lib" 2>/dev/null)" ]; then
    echo "  Libraries: $(ls "$INSTALL_DIR/lib/" | wc -l) files"
else
    echo "  Libraries: $LIB_TYPE (bundled in binary)"
fi
echo "  Headers: $(find "$INSTALL_DIR/include" -type f 2>/dev/null | wc -l) files"
echo "  Share: $(find "$INSTALL_DIR/share" -type f 2>/dev/null | wc -l) files"
echo ""

# Create README for the artifact (quoted heredoc + sed for variable substitution)
cat > "$INSTALL_DIR/README.txt" << 'EOF'
GROMACS @@GMX_VERSION@@ - @@GMX_GPU@@ GPU Build
===============================

Build Configuration:
  Version:        @@GMX_VERSION@@
  Build type:     @@BUILD_TYPE@@
  Libraries:      @@LIB_TYPE@@ (bundled in binary)
  SIMD:           @@GMX_SIMD@@
  Threading:      @@THREADING@@
  GPU:            @@GPU_LABEL@@
  Precision:      @@PRECISION@@
  Platform:       @@PLATFORM@@
  CUDA:           @@CUDA_VERSION@@ Toolkit

Installation:
  tar -xjf built_artefact.tar.bz2
  ./setup_gromacs.sh

Runtime Requirements (@@PLATFORM@@):
  sudo apt update
  sudo apt install @@RUNTIME_DEPS@@

Usage:
  source bin/GMXRC
  @@GMX_BIN@@ --version

Supported GPUs:
  Consumer: RTX 30 series (3060-3090 Ti)
             RTX 40 series (4050-4090)
             RTX 50 series
  Datacenter: A100, A10, A30, A40 (Ampere)
              H100, H200 (Hopper)
              L40, L40S (Ada)
  Compute Capabilities: 8.6, 8.9, 9.0, 12.0

For more information:
  https://manual.gromacs.org/current/
  https://www.gromacs.org/

Contents:
  bin/        - Executables (gmx, GMXRC, completion scripts)
  include/    - Header files for development
  share/      - Force fields, templates, man pages
EOF

sed -i \
    -e "s|@@GMX_VERSION@@|$GMX_VERSION|g" \
    -e "s|@@BUILD_TYPE@@|$BUILD_TYPE|g" \
    -e "s|@@LIB_TYPE@@|$LIB_TYPE|g" \
    -e "s|@@GMX_SIMD@@|$GMX_SIMD|g" \
    -e "s|@@THREADING@@|$THREADING|g" \
    -e "s|@@GPU_LABEL@@|$GPU_LABEL|g" \
    -e "s|@@PRECISION@@|$PRECISION|g" \
    -e "s|@@PLATFORM@@|$PLATFORM|g" \
    -e "s|@@CUDA_VERSION@@|$CUDA_VERSION|g" \
    -e "s|@@RUNTIME_DEPS@@|$RUNTIME_DEPS|g" \
    -e "s|@@GMX_GPU@@|$GMX_GPU|g" \
    -e "s|@@GMX_BIN@@|$GMX_BIN|g" \
    "$INSTALL_DIR/README.txt"

# Conditional multi-GPU section
if [ "$THREADING" = "External MPI" ]; then
    cat >> "$INSTALL_DIR/README.txt" << 'EOF'

  Multi-GPU (MPI):
    mpirun -np 4 @@GMX_BIN@@ mdrun -deffnm simulation
EOF
    sed -i "s|@@GMX_BIN@@|$GMX_BIN|g" "$INSTALL_DIR/README.txt"
else
    cat >> "$INSTALL_DIR/README.txt" << 'EOF'

  Multi-GPU (Thread-MPI):
    @@GMX_BIN@@ mdrun -ntmpi 4 -deffnm simulation
EOF
    sed -i "s|@@GMX_BIN@@|$GMX_BIN|g" "$INSTALL_DIR/README.txt"
fi

# Create setup helper script (quoted heredoc + sed)
cat > "$INSTALL_DIR/setup_gromacs.sh" << 'EOF'
#!/bin/bash
# GROMACS environment setup script (relocatable)
GMX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$GMX_DIR/bin:$PATH"
export GMXBIN="$GMX_DIR/bin"
export GMXDATA="$GMX_DIR/share/gromacs"
export GROMACS_DIR="$GMX_DIR"
echo "GROMACS environment set up"
echo "GMX bin: $GMX_DIR/bin"
echo "GMX version: $($GMX_DIR/bin/@@GMX_BIN@@ --version 2>&1 | head -1)"
EOF
sed -i "s|@@GMX_BIN@@|$GMX_BIN|g" "$INSTALL_DIR/setup_gromacs.sh"
chmod +x "$INSTALL_DIR/setup_gromacs.sh"

# Replace GMXRC with relocatable versions
echo "Creating relocatable GMXRC scripts..."

cat > "$INSTALL_DIR/bin/GMXRC" << 'GMXRC_EOF'
#!/bin/sh
# Relocatable GMXRC - detects installation directory automatically
GMXRC_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$GMXRC_DIR/GMXRC.bash"
GMXRC_EOF

cat > "$INSTALL_DIR/bin/GMXRC.bash" << 'GMXRC_BASH_EOF'
#!/bin/bash
# Relocatable GROMACS environment setup for bash/zsh
# Detects installation directory from script location

GMXBIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GMXPREFIX="$(dirname "$GMXBIN")"
GMXLDLIB="$GMXPREFIX/lib"
GMXMAN="$GMXPREFIX/share/man"
GMXDATA="$GMXPREFIX/share/gromacs"
GROMACS_DIR="$GMXPREFIX"

# Remove old GROMACS paths from PATH if present
if [ -n "$PATH" ]; then
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/gromacs' | grep -v '/GMXBIN' | tr '\n' ':' | sed 's/:$//')
fi

# Remove old GROMACS paths from LD_LIBRARY_PATH if present
if [ -n "$LD_LIBRARY_PATH" ]; then
    LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -v '/gromacs' | tr '\n' ':' | sed 's/:$//')
fi

# Remove old GROMACS paths from MANPATH if present
if [ -n "$MANPATH" ]; then
    MANPATH=$(echo "$MANPATH" | tr ':' '\n' | grep -v '/gromacs' | tr '\n' ':' | sed 's/:$//')
fi

# Add new paths
export PATH="$GMXBIN:$PATH"
if [ -d "$GMXLDLIB" ]; then
    export LD_LIBRARY_PATH="$GMXLDLIB:$LD_LIBRARY_PATH"
fi
export MANPATH="$GMXMAN:$MANPATH"
export GMXBIN GMXLDLIB GMXMAN GMXDATA GROMACS_DIR

# Bash completion support
if [ -n "$BASH_VERSION" ] && [ -f "$GMXBIN/gmx-completion.bash" ]; then
    source "$GMXBIN/gmx-completion.bash"
    for cfile in "$GMXBIN"/gmx-completion-*.bash; do
        [ -f "$cfile" ] && source "$cfile"
    done
fi
GMXRC_BASH_EOF

cat > "$INSTALL_DIR/bin/GMXRC.csh" << 'GMXRC_CSH_EOF'
#!/bin/csh
# Relocatable GROMACS environment setup for csh/tcsh
set GMXRC_DIR = "`dirname $0`"
set GMXBIN = "`cd $GMXRC_DIR && pwd`"
set GMXPREFIX = "`dirname $GMXBIN`"
setenv GMXBIN "$GMXBIN"
setenv GMXLDLIB "$GMXPREFIX/lib"
setenv GMXMAN "$GMXPREFIX/share/man"
setenv GMXDATA "$GMXPREFIX/share/gromacs"
setenv GROMACS_DIR "$GMXPREFIX"
setenv PATH "${GMXBIN}:${PATH}"
if ($?LD_LIBRARY_PATH) then
    setenv LD_LIBRARY_PATH "${GMXLDLIB}:${LD_LIBRARY_PATH}"
else
    setenv LD_LIBRARY_PATH "${GMXLDLIB}"
endif
GMXRC_CSH_EOF

cat > "$INSTALL_DIR/bin/GMXRC.zsh" << 'GMXRC_ZSH_EOF'
#!/bin/zsh
# Relocatable GROMACS environment setup for zsh
GMXRC_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$GMXRC_DIR/GMXRC.bash"
GMXRC_ZSH_EOF

chmod +x "$INSTALL_DIR/bin/GMXRC" "$INSTALL_DIR/bin/GMXRC.bash" "$INSTALL_DIR/bin/GMXRC.csh" "$INSTALL_DIR/bin/GMXRC.zsh"
echo "Relocatable GMXRC scripts created"

# Create the artifact
echo "Creating artifact tarball..."
WORKING_DIR=$(pwd)
cd "$INSTALL_DIR"
tar -cjf "$WORKING_DIR/$ARTIFACT_NAME" .
cd "$WORKING_DIR"

# Verify artifact was created
if [ ! -f "$ARTIFACT_NAME" ]; then
    echo "::error::$ARTIFACT_NAME was not created"
    exit 1
fi

ARTIFACT_SIZE_HR=$(du -h "$ARTIFACT_NAME" | cut -f1)

echo ""
echo "Postbuild complete"
echo "Artifact created: $ARTIFACT_NAME ($ARTIFACT_SIZE_HR)"
echo ""

# Show artifact contents (first 20 files)
echo "Artifact contents (first 20 files):"
tar -tjf "$ARTIFACT_NAME" | head -20
echo "..."
echo ""

# Verify artifact integrity
echo "Verifying artifact integrity..."
if tar -tjf "$ARTIFACT_NAME" | grep -qE "bin/${GMX_BIN}$"; then
    echo "::pass::GROMACS binary found in artifact"
else
    echo "::error::GROMACS binary not found in artifact"
    exit 1
fi

if tar -tjf "$ARTIFACT_NAME" | grep -q "bin/GMXRC"; then
    echo "::pass::GMXRC setup script found in artifact"
else
    echo "::error::GMXRC not found in artifact"
    exit 1
fi

if tar -tjf "$ARTIFACT_NAME" | grep -q "share/gromacs/top/"; then
    echo "::pass::Force field files found in artifact"
else
    echo "::error::Force field files not found in artifact"
    exit 1
fi

echo ""
echo "==================================="
echo "Artifact verification complete"
echo "==================================="
echo ""
