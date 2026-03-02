#!/bin/bash
set -e

echo "==================================="
echo "POSTBUILD: Creating build artifact"
echo "==================================="

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Example: Package build artifacts
# Uncomment and modify as needed:
# 
# # Define what to include in the artifact
# ARTIFACT_CONTENTS=(
#     "build/bin"
#     "build/lib"
#     "build/include"
# )
# 
# # Create the artifact
# tar -cjf built_artefact.tar.bz2 "${ARTIFACT_CONTENTS[@]}"

# For demonstration: create an empty artifact
# Replace this with actual build output
if [ ! -f "built_artefact.tar.bz2" ]; then
    echo "Creating placeholder artifact..."
    echo "Build artifact placeholder" > artifact_placeholder.txt
    tar -cjf built_artefact.tar.bz2 artifact_placeholder.txt
    rm artifact_placeholder.txt
fi

# Verify artifact was created
if [ ! -f "built_artefact.tar.bz2" ]; then
    echo "::error::built_artefact.tar.bz2 was not created"
    exit 1
fi

ARTIFACT_SIZE=$(stat -c%s "built_artefact.tar.bz2" 2>/dev/null || stat -f%z "built_artefact.tar.bz2" 2>/dev/null || echo "unknown")

echo "Postbuild complete"
echo "Artifact created: built_artefact.tar.bz2 ($ARTIFACT_SIZE bytes)"
echo ""
