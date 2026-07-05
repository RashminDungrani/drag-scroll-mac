#!/bin/bash
# ─────────────────────────────────────────────────────────────
# build.sh — Compile DragScroll and package into a .app bundle
# ─────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DragScroll"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS}/MacOS"

echo "╔══════════════════════════════════════════╗"
echo "║       Building DragScroll.app            ║"
echo "╚══════════════════════════════════════════╝"

# Clean previous build
rm -rf "${BUILD_DIR}"
mkdir -p "${MACOS_DIR}"

# Compile Swift → native binary (optimized)
echo "⟹  Compiling main.swift ..."
swiftc \
    -o "${MACOS_DIR}/${APP_NAME}" \
    "${SCRIPT_DIR}/main.swift" \
    -framework Cocoa \
    -framework CoreGraphics \
    -O \
    -whole-module-optimization

# Copy Info.plist
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS}/Info.plist"

# Copy App Icon
echo "⟹  Adding App Icon..."
mkdir -p "${CONTENTS}/Resources"
cp "${SCRIPT_DIR}/AppIcon.icns" "${CONTENTS}/Resources/AppIcon.icns"

# Package into ZIP for distribution
echo "⟹  Creating distribution archive..."
cd "${BUILD_DIR}"
zip -qr "${APP_NAME}.zip" "${APP_NAME}.app"
cd "${SCRIPT_DIR}"

# Install to /Applications
echo "⟹  Installing to /Applications..."
rm -rf "/Applications/${APP_NAME}.app"
cp -R "${APP_BUNDLE}" /Applications/

echo ""
echo "✅  Build & Install successful!"
echo "    App installed to: /Applications/${APP_NAME}.app"
echo "    Release zip created at: ${BUILD_DIR}/${APP_NAME}.zip"
echo ""
echo "── Next steps ──────────────────────────────"
echo "  1. Open the app from your Launchpad or Applications folder"
echo "  2. Grant Accessibility access when prompted"
echo "     (System Settings → Privacy & Security → Accessibility)"
echo "  3. Look for the ⇕ icon in your menu bar"
echo "  4. Hold Mouse Button 5 + Drag to scroll!"
echo "─────────────────────────────────────────────"
