#!/bin/bash
set -euo pipefail

APP_NAME="Scry"
VERSION="${1:-1.0.0}"
BUILD_DIR="${2:-app/DerivedData/Build/Products/Release}"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING_DIR=$(mktemp -d)

echo "Creating DMG for ${APP_NAME} v${VERSION}..."

# Check the app exists
if [ ! -d "${BUILD_DIR}/${APP_NAME}.app" ]; then
    echo "Error: ${BUILD_DIR}/${APP_NAME}.app not found."
    echo "Build the Release configuration first:"
    echo "  cd app && xcodebuild -scheme Scry -configuration Release -derivedDataPath DerivedData build"
    exit 1
fi

# Stage the app
cp -R "${BUILD_DIR}/${APP_NAME}.app" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

# Create DMG
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov -format UDZO \
    "${DMG_NAME}"

# Cleanup
rm -rf "${STAGING_DIR}"

echo "Created ${DMG_NAME}"
