#!/bin/bash
set -e

echo "==================================="
echo "POSTBUILD: Creating build artifact"
echo "==================================="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Verify build directory exists
if [ ! -d "build" ]; then
    echo "::error::Build directory not found"
    exit 1
fi

# Verify the binary was built
if [ ! -f "build/hello" ]; then
    echo "::error::Binary 'build/hello' not found"
    exit 1
fi

# Create artifact directory structure
echo "Creating artifact directory structure..."
mkdir -p artifact/bin

# Copy the binary
cp build/hello artifact/bin/

# Create README for the artifact
cat > artifact/README.txt <<EOF
Hello World C++ Application
Built by GitHub Actions

Contents:
  bin/hello - The Hello World executable

To run:
  ./bin/hello
EOF

# Create the artifact
echo "Creating artifact tarball..."
tar -cjf built_artefact.tar.bz2 -C artifact .

# Clean up
rm -rf artifact

# Verify artifact was created
if [ ! -f "built_artefact.tar.bz2" ]; then
    echo "::error::built_artefact.tar.bz2 was not created"
    exit 1
fi

ARTIFACT_SIZE=$(stat -c%s "built_artefact.tar.bz2" 2>/dev/null || stat -f%z "built_artefact.tar.bz2" 2>/dev/null || echo "unknown")

echo "Postbuild complete"
echo "Artifact created: built_artefact.tar.bz2 ($ARTIFACT_SIZE bytes)"

# Show artifact contents
echo ""
echo "Artifact contents:"
tar -tjf built_artefact.tar.bz2
echo ""
