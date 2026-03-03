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
if [ ! -f "$INSTALL_DIR/bin/gmx" ]; then
    echo "::error::GROMACS binary not found at $INSTALL_DIR/bin/gmx"
    exit 1
fi

echo "GROMACS installation found at: $INSTALL_DIR"
echo ""

# Display installation contents
echo "Installation contents:"
echo "  Binaries: $(ls $INSTALL_DIR/bin/ | wc -l) files"
if [ -d "$INSTALL_DIR/lib" ] && [ "$(ls -A $INSTALL_DIR/lib 2>/dev/null)" ]; then
    echo "  Libraries: $(ls $INSTALL_DIR/lib/ | wc -l) files"
else
    echo "  Libraries: Static (bundled in binary)"
fi
echo "  Headers: $(find $INSTALL_DIR/include -type f 2>/dev/null | wc -l) files"
echo "  Share: $(find $INSTALL_DIR/share -type f 2>/dev/null | wc -l) files"
echo ""

# Create README for the artifact
cat > "$INSTALL_DIR/README.txt" << 'EOF'
GROMACS 2026.0 - CPU Build
==========================

Build Configuration:
  Version:        2026.0
  Build type:     Release
  Libraries:      Static (bundled in binary)
  SIMD:           AVX2_256
  Threading:      Thread-MPI
  GPU:            OFF
  Precision:      Single/Mixed
  Platform:       Ubuntu 24.04 AMD64

Installation:
  tar -xjf built_artefact.tar.bz2
  ./setup_gromacs.sh

Runtime Requirements (Ubuntu 24.04):
  sudo apt update
  sudo apt install libgomp1

Usage:
  source bin/GMXRC
  gmx --version

For more information:
  https://manual.gromacs.org/current/
  https://www.gromacs.org/

Contents:
  bin/        - Executables (gmx, GMXRC, completion scripts)
  include/    - Header files for development
  share/      - Force fields, templates, man pages
EOF

# Create setup helper script
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
echo "GMX version: $($GMX_DIR/bin/gmx --version 2>&1 | head -1)"
EOF
chmod +x "$INSTALL_DIR/setup_gromacs.sh"

# Replace GMXRC with relocatable versions
echo "Creating relocatable GMXRC scripts..."

# GMXRC - shell-agnostic wrapper that detects script location
cat > "$INSTALL_DIR/bin/GMXRC" << 'GMXRC_EOF'
#!/bin/sh
# Relocatable GMXRC - detects installation directory automatically
GMXRC_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$GMXRC_DIR/GMXRC.bash"
GMXRC_EOF

# GMXRC.bash - bash/zsh configuration with relocatable paths
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

# GMXRC.csh - csh/tcsh configuration with relocatable paths
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

# GMXRC.zsh - zsh configuration (delegates to bash version)
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
if tar -tjf built_artefact.tar.bz2 | grep -q "bin/gmx"; then
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
