#!/bin/bash
# Package SPM build output into a macOS .app bundle
# Usage: ./Scripts/package_app.sh [debug|release] [arch]
#   config: debug or release (default: release)
#   arch: x86_64 or arm64 (default: current machine arch)

set -euo pipefail

CONFIG="${1:-release}"
ARCH="${2:-$(uname -m)}"
APP_NAME="GitHubNotifier"

# Determine build directory based on whether cross-compiling
if [ -d ".build/${ARCH}-apple-macosx/${CONFIG}" ]; then
    # Cross-compilation build path
    BUILD_DIR=".build/${ARCH}-apple-macosx/${CONFIG}"
else
    # Local build path
    BUILD_DIR=".build/${CONFIG}"
fi

BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "===> Packaging ${APP_NAME}.app (${CONFIG}, ${ARCH})..."

# Create app bundle structure
mkdir -p "${BUNDLE}/Contents/MacOS"
mkdir -p "${BUNDLE}/Contents/Resources"

# Copy binary
if [ -f "${BUILD_DIR}/${APP_NAME}" ]; then
    cp "${BUILD_DIR}/${APP_NAME}" "${BUNDLE}/Contents/MacOS/"
else
    echo "❌ Error: Binary not found at ${BUILD_DIR}/${APP_NAME}"
    echo "   Run 'swift build -c ${CONFIG}' first."
    exit 1
fi

# Copy Info.plist
if [ -f "Sources/GitHubNotifier/Info.plist" ]; then
    cp "Sources/GitHubNotifier/Info.plist" "${BUNDLE}/Contents/"
fi

# Copy Assets.xcassets (compile with actool if available, otherwise copy)
ASSETS_PATH="Sources/GitHubNotifier/Resources/Assets.xcassets"
if [ -d "${ASSETS_PATH}" ]; then
    if command -v actool &> /dev/null; then
        actool --compile "${BUNDLE}/Contents/Resources" \
               --platform macosx \
               --minimum-deployment-target 14.0 \
               --app-icon AppIcon \
               --output-partial-info-plist /dev/null \
               "${ASSETS_PATH}" 2>/dev/null || cp -r "${ASSETS_PATH}" "${BUNDLE}/Contents/Resources/"
    else
        cp -r "${ASSETS_PATH}" "${BUNDLE}/Contents/Resources/"
    fi
fi

# Copy localization resources
for lproj in Sources/GitHubNotifier/Resources/*.lproj; do
    if [ -d "$lproj" ]; then
        cp -r "$lproj" "${BUNDLE}/Contents/Resources/"
    fi
done

# Copy Sparkle framework
SPARKLE_SRC=".build/${ARCH}-apple-macosx/${CONFIG}/Sparkle.framework"
if [ -d "${SPARKLE_SRC}" ]; then
    echo "===> Copying Sparkle.framework..."
    mkdir -p "${BUNDLE}/Contents/Frameworks"
    cp -R "${SPARKLE_SRC}" "${BUNDLE}/Contents/Frameworks/"
    
    # Fix rpath to find Sparkle in Frameworks folder
    echo "===> Fixing rpath for Sparkle..."
    install_name_tool -add_rpath "@executable_path/../Frameworks" "${BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
else
    echo "⚠️  Warning: Sparkle.framework not found at ${SPARKLE_SRC}"
fi

# Self-sign the app (with frameworks)
codesign --force --deep --sign - "${BUNDLE}"

echo "✅ Created ${BUNDLE}"
echo "   Run: open ${BUNDLE}"
