#!/bin/bash
set -e

VARIANT_INDEX="${1:?Usage: postbuild.sh <variant-index>}"

source "$(dirname "$0")/build-config-${VARIANT_INDEX}.sh"

echo "==================================="
echo "POSTBUILD: Creating GROMACS artifact (variant $VARIANT_INDEX)"
echo "==================================="

if [ ! -d "$INSTALL_DIR" ]; then
    echo "::error::Installation directory not found: $INSTALL_DIR"
    exit 1
fi

if [ ! -f "$INSTALL_DIR/bin/$GMX_BIN" ]; then
    echo "::error::GROMACS binary not found at $INSTALL_DIR/bin/$GMX_BIN"
    exit 1
fi

echo "GROMACS installation found at: $INSTALL_DIR"
echo ""

echo "Dynamic library dependencies:"
ldd "$INSTALL_DIR/bin/$GMX_BIN" || true
echo ""

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

if [ "$GMX_GPU" = "CUDA" ]; then
    _TITLE="GROMACS $GMX_VERSION - CUDA GPU Build"
else
    _TITLE="GROMACS $GMX_VERSION - CPU Build"
fi

cat > "$INSTALL_DIR/README.txt" << EOF
$_TITLE
===============================

Build Configuration:
  Version:        $GMX_VERSION
  Build type:     $BUILD_TYPE
  SIMD:           $GMX_SIMD
  Precision:      $PRECISION
  Threading:      $THREADING
  GPU:            $GPU_LABEL
  Platform:       $PLATFORM
EOF

if [ "$GMX_GPU" = "CUDA" ]; then
    cat >> "$INSTALL_DIR/README.txt" << EOF
  CUDA:           $CUDA_VERSION Toolkit
EOF
fi

cat >> "$INSTALL_DIR/README.txt" << 'EOF'

Installation:
  tar -xjf @@ARTIFACT_NAME@@
  ./setup_gromacs.sh

Runtime Requirements (@@PLATFORM@@):
  sudo apt update
  sudo apt install @@RUNTIME_DEPS@@

Usage:
  source bin/GMXRC
  @@GMX_BIN@@ --version
EOF

sed -i \
    -e "s|@@ARTIFACT_NAME@@|$ARTIFACT_NAME|g" \
    -e "s|@@PLATFORM@@|$PLATFORM|g" \
    -e "s|@@RUNTIME_DEPS@@|$RUNTIME_DEPS|g" \
    -e "s|@@GMX_BIN@@|$GMX_BIN|g" \
    "$INSTALL_DIR/README.txt"

if [ "$GMX_GPU" = "CUDA" ]; then
    cat >> "$INSTALL_DIR/README.txt" << 'EOF'

Supported GPUs:
  Consumer: RTX 30 series (3060-3090 Ti)
             RTX 40 series (4050-4090)
              RTX 50 series
  Datacenter: A100, A10, A30, A40 (Ampere)
               H100, H200 (Hopper)
               L40, L40S (Ada)
  Compute Capabilities: 8.6, 8.9, 9.0, 12.0
EOF
fi

cat >> "$INSTALL_DIR/README.txt" << 'EOF'

For more information:
  https://manual.gromacs.org/current/
  https://www.gromacs.org/

Contents:
  bin/        - Executables (@@GMX_BIN@@, GMXRC, completion scripts)
  include/    - Header files for development
  share/      - Force fields, templates, man pages
EOF

sed -i "s|@@GMX_BIN@@|$GMX_BIN|g" "$INSTALL_DIR/README.txt"

if [ "$THREADING" = "External MPI" ]; then
    cat >> "$INSTALL_DIR/README.txt" << EOF

  Multi-GPU (MPI):
    mpirun -np 4 $GMX_BIN mdrun -deffnm simulation
EOF
else
    cat >> "$INSTALL_DIR/README.txt" << EOF

  Multi-GPU (Thread-MPI):
    $GMX_BIN mdrun -ntmpi 4 -deffnm simulation
EOF
fi

cat > "$INSTALL_DIR/setup_gromacs.sh" << 'EOF'
#!/bin/bash
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

echo "Creating relocatable GMXRC scripts..."

cat > "$INSTALL_DIR/bin/GMXRC" << 'GMXRC_EOF'
#!/bin/sh
GMXRC_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$GMXRC_DIR/GMXRC.bash"
GMXRC_EOF

cat > "$INSTALL_DIR/bin/GMXRC.bash" << 'GMXRC_BASH_EOF'
#!/bin/bash
GMXBIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GMXPREFIX="$(dirname "$GMXBIN")"
GMXLDLIB="$GMXPREFIX/lib"
GMXMAN="$GMXPREFIX/share/man"
GMXDATA="$GMXPREFIX/share/gromacs"
GROMACS_DIR="$GMXPREFIX"

if [ -n "$PATH" ]; then
    PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/gromacs' | grep -v "$GMXBIN" | tr '\n' ':' | sed 's/:$//')
fi

if [ -n "$LD_LIBRARY_PATH" ]; then
    LD_LIBRARY_PATH=$(echo "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -v '/gromacs' | grep -v "$GMXLDLIB" | tr '\n' ':' | sed 's/:$//')
fi

if [ -n "$MANPATH" ]; then
    MANPATH=$(echo "$MANPATH" | tr ':' '\n' | grep -v '/gromacs' | grep -v "$GMXMAN" | tr '\n' ':' | sed 's/:$//')
fi

export PATH="$GMXBIN:$PATH"
if [ -d "$GMXLDLIB" ]; then
    export LD_LIBRARY_PATH="$GMXLDLIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
export MANPATH="$GMXMAN${MANPATH:+:$MANPATH}"
export GMXBIN GMXLDLIB GMXMAN GMXDATA GROMACS_DIR

if [ -n "$BASH_VERSION" ] && [ -f "$GMXBIN/gmx-completion.bash" ]; then
    source "$GMXBIN/gmx-completion.bash"
    for cfile in "$GMXBIN"/gmx-completion-*.bash; do
        [ -f "$cfile" ] && source "$cfile"
    done
fi
GMXRC_BASH_EOF

cat > "$INSTALL_DIR/bin/GMXRC.csh" << 'GMXRC_CSH_EOF'
#!/bin/csh
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
GMXRC_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$GMXRC_DIR/GMXRC.bash"
GMXRC_ZSH_EOF

chmod +x "$INSTALL_DIR/bin/GMXRC" "$INSTALL_DIR/bin/GMXRC.bash" "$INSTALL_DIR/bin/GMXRC.csh" "$INSTALL_DIR/bin/GMXRC.zsh"
echo "Relocatable GMXRC scripts created"

echo "Creating artifact tarball..."
WORKING_DIR=$(pwd)
cd "$INSTALL_DIR"
tar -cjf "$WORKING_DIR/$ARTIFACT_NAME" .
cd "$WORKING_DIR"

if [ ! -f "$ARTIFACT_NAME" ]; then
    echo "::error::$ARTIFACT_NAME was not created"
    exit 1
fi

ARTIFACT_SIZE_HR=$(du -h "$ARTIFACT_NAME" | cut -f1)

echo ""
echo "Postbuild complete (variant $VARIANT_INDEX)"
echo "Artifact created: $ARTIFACT_NAME ($ARTIFACT_SIZE_HR)"
echo ""

echo "Artifact contents (first 20 files):"
tar -tjf "$ARTIFACT_NAME" | head -20
echo "..."
echo ""

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
echo "Artifact verification complete (variant $VARIANT_INDEX)"
echo "==================================="
echo ""
