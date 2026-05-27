#!/bin/bash
set -e

VARIANT_COUNT="${1:?Usage: snapshot.sh <variant-count>}"

echo "==================================="
echo "SNAPSHOT: Creating build settings snapshot"
echo "==================================="

SNAPSHOT_FILES=""

if [ ! -f "target-cmake.json" ]; then
    echo "::error::target-cmake.json not found"
    exit 1
fi
SNAPSHOT_FILES="$SNAPSHOT_FILES target-cmake.json"

for i in $(seq 0 $((VARIANT_COUNT - 1))); do
    CONFIG_FILE="build-config-${i}.sh"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "::error::$CONFIG_FILE not found"
        exit 1
    fi
    SNAPSHOT_FILES="$SNAPSHOT_FILES $CONFIG_FILE"
done

echo "Bundling into build_settings_snapshot.tar.bz2..."
echo "  Files:$SNAPSHOT_FILES"
echo ""

tar -cjf build_settings_snapshot.tar.bz2 $SNAPSHOT_FILES

if [ ! -f "build_settings_snapshot.tar.bz2" ]; then
    echo "::error::build_settings_snapshot.tar.bz2 was not created"
    exit 1
fi

SNAPSHOT_SIZE_HR=$(du -h build_settings_snapshot.tar.bz2 | cut -f1)

echo ""
echo "Snapshot created: build_settings_snapshot.tar.bz2 ($SNAPSHOT_SIZE_HR)"
echo ""

echo "Contents:"
tar -tjf build_settings_snapshot.tar.bz2
echo ""

echo "==================================="
echo "Snapshot complete"
echo "==================================="
echo ""
