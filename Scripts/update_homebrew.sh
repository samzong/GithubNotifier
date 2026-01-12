#!/bin/bash
set -e

# Required environment variables
: "${GH_PAT:?GH_PAT environment variable is required}"
: "${VERSION:?VERSION is required}"
: "${MARKETING_SEMVER:?MARKETING_SEMVER is required}"
: "${APP_NAME:?APP_NAME is required}"
: "${HOMEBREW_TAP_REPO:?HOMEBREW_TAP_REPO is required}"
: "${CASK_FILE:?CASK_FILE is required}"
: "${BRANCH_NAME:?BRANCH_NAME is required}"

echo "===> Starting Homebrew cask update process..."
echo "===> Current version information:"
echo "    - VERSION: ${VERSION}"
echo "    - MARKETING_SEMVER: ${MARKETING_SEMVER}"

rm -rf tmp && mkdir -p tmp

echo "===> Downloading DMG files..."
curl -sfL -o "tmp/${APP_NAME}-x86_64.dmg" "https://github.com/samzong/${APP_NAME}/releases/download/v${MARKETING_SEMVER}/${APP_NAME}-x86_64.dmg"
curl -sfL -o "tmp/${APP_NAME}-arm64.dmg" "https://github.com/samzong/${APP_NAME}/releases/download/v${MARKETING_SEMVER}/${APP_NAME}-arm64.dmg"

echo "===> Calculating SHA256 checksums..."
X86_64_SHA256=$(shasum -a 256 "tmp/${APP_NAME}-x86_64.dmg" | cut -d ' ' -f 1)
ARM64_SHA256=$(shasum -a 256 "tmp/${APP_NAME}-arm64.dmg" | cut -d ' ' -f 1)

echo "    - x86_64 SHA256: $X86_64_SHA256"
echo "    - arm64 SHA256: $ARM64_SHA256"

echo "===> Cloning Homebrew tap repository..."
cd tmp
git clone "https://${GH_PAT}@github.com/samzong/${HOMEBREW_TAP_REPO}.git"
cd "${HOMEBREW_TAP_REPO}"

echo "    - Creating new branch: ${BRANCH_NAME}"
git checkout -b "${BRANCH_NAME}"

echo "===> Updating cask file..."
if [ -f "${CASK_FILE}" ]; then
    echo "    - Updating existing cask file with sed..."
    echo "    - Updating version to ${MARKETING_SEMVER}"
    sed -i '' "s/version \"[^\"]*\"/version \"${MARKETING_SEMVER}\"/" "${CASK_FILE}"
    
    if grep -q "on_arm" "${CASK_FILE}"; then
        echo "    - Updating arm64 SHA256 to ${ARM64_SHA256}"
        sed -i '' "/on_arm/,/end/{s/sha256 \"[^\"]*\"/sha256 \"${ARM64_SHA256}\"/;}" "${CASK_FILE}"
        echo "    - Updating x86_64 SHA256 to ${X86_64_SHA256}"
        sed -i '' "/on_intel/,/end/{s/sha256 \"[^\"]*\"/sha256 \"${X86_64_SHA256}\"/;}" "${CASK_FILE}"
    else
        echo "❌ Unknown cask format, cannot update SHA256 values"
        exit 1
    fi
else
    echo "❌ Error: Cask file not found. Please create it manually first."
    exit 1
fi

echo "===> Checking for changes..."
if ! git diff --quiet "${CASK_FILE}"; then
    echo "    - Changes detected, creating pull request..."
    git add "${CASK_FILE}"
    git config user.name "GitHub Actions"
    git config user.email "actions@github.com"
    git commit -m "chore: update ${APP_NAME} to v${MARKETING_SEMVER}"
    git push -u origin "${BRANCH_NAME}"
    
    PR_DATA=$(printf '{"title":"chore: update %s to v%s","body":"Auto-generated PR\\n- Version: %s\\n- x86_64 SHA256: %s\\n- arm64 SHA256: %s","head":"%s","base":"main"}' \
        "${APP_NAME}" "${MARKETING_SEMVER}" "${MARKETING_SEMVER}" "${X86_64_SHA256}" "${ARM64_SHA256}" "${BRANCH_NAME}")
        
    curl -X POST \
        -H "Authorization: token ${GH_PAT}" \
        -H "Content-Type: application/json" \
        "https://api.github.com/repos/samzong/${HOMEBREW_TAP_REPO}/pulls" \
        -d "${PR_DATA}"
        
    echo "✅ Pull request created successfully"
else
    echo "❌ No changes detected in cask file"
    exit 1
fi

echo "===> Cleaning up temporary files..."
cd ../..
rm -rf tmp
echo "✅ Homebrew cask update process completed"
