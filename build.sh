#!/bin/bash
###############################################################################
# GuildHistorian Build Script
# Creates a release-ready package for World of Warcraft retail.
#
# Usage:
#   ./build.sh          # Builds using version from .toc file
#   ./build.sh 1.0.1    # Builds with a custom version number
#
# Output:
#   dist/GuildHistorian-<version>.zip    - Ready to extract into WoW AddOns folder
#   dist/GuildHistorian/                 - Unpacked addon folder
#
# Installation:
#   Extract the zip (or copy the GuildHistorian folder) to:
#     Windows: C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns\
#     macOS:   /Applications/World of Warcraft/_retail_/Interface/AddOns/
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Determine version
if [ $# -ge 1 ]; then
    VERSION="$1"
else
    VERSION=$(grep '## Version:' GuildHistorian.toc | sed 's/## Version: *//')
fi

if [ -z "$VERSION" ]; then
    echo "ERROR: Could not determine version. Pass it as an argument or ensure GuildHistorian.toc has ## Version."
    exit 1
fi

echo "=============================================="
echo "  GuildHistorian Build Script"
echo "  Version: $VERSION"
echo "=============================================="

# Run tests first
echo ""
echo "[Build] Running test suite..."
if ! lua Tests/run_tests.lua; then
    echo ""
    echo "[Build] ERROR: Tests failed. Fix failures before building."
    exit 1
fi

echo ""
echo "[Build] Tests passed. Building release package..."

# Clean previous build
DIST_DIR="$SCRIPT_DIR/dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR/GuildHistorian"

# Copy addon files (exclude development-only files)
rsync -a \
    --exclude='.git' \
    --exclude='.github' \
    --exclude='.gitignore' \
    --exclude='.editorconfig' \
    --exclude='.luacheckrc' \
    --exclude='CONTRIBUTING.md' \
    --exclude='Tests/' \
    --exclude='dist/' \
    --exclude='build.sh' \
    --exclude='*.zip' \
    --exclude='.DS_Store' \
    ./ "$DIST_DIR/GuildHistorian/"

# Create the zip file
cd "$DIST_DIR"
ZIP_NAME="GuildHistorian-${VERSION}.zip"
zip -r "$ZIP_NAME" GuildHistorian/ -x '*.DS_Store'

echo ""
echo "=============================================="
echo "  Build Complete!"
echo "=============================================="
echo ""
echo "  Output files:"
echo "    $DIST_DIR/$ZIP_NAME"
echo "    $DIST_DIR/GuildHistorian/  (unpacked)"
echo ""
echo "  Installation (Retail WoW):"
echo "    1. Extract the zip OR copy the 'GuildHistorian' folder to:"
echo ""
echo "       Windows:"
echo "         C:\\Program Files (x86)\\World of Warcraft\\_retail_\\Interface\\AddOns\\"
echo ""
echo "       macOS:"
echo "         /Applications/World of Warcraft/_retail_/Interface/AddOns/"
echo ""
echo "    2. Restart WoW or type /reload in-game"
echo "    3. Type /gh to open the Guild Historian timeline"
echo ""
echo "  File listing:"
cd "$DIST_DIR/GuildHistorian"
find . -type f | sort | sed 's|^./|    |'
echo ""

# Show zip size
ZIP_SIZE=$(ls -lh "$DIST_DIR/$ZIP_NAME" | awk '{print $5}')
echo "  Package size: $ZIP_SIZE"
echo ""
