#!/bin/bash
# Quick compile and run for development
# Usage: ./Scripts/compile_and_run.sh [debug|release]

set -euo pipefail

CONFIG="${1:-debug}"
APP_NAME="GitHubNotifier"
ARCH=$(uname -m)

echo "===> Stopping any running ${APP_NAME} instances..."
pkill -x "${APP_NAME}" 2>/dev/null || true

echo "===> Building ${APP_NAME} (${CONFIG})..."
swift build -c "${CONFIG}"

echo "===> Packaging app bundle..."
./Scripts/package_app.sh "${CONFIG}"

echo "===> Launching ${APP_NAME}..."
open ".build/${ARCH}-apple-macosx/${CONFIG}/${APP_NAME}.app"
