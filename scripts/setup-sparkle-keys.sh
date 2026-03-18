#!/bin/bash
set -euo pipefail

echo "=== Sparkle EdDSA Key Setup ==="
echo ""

# Check if Sparkle's generate_keys is available
GENERATE_KEYS=$(find ~/Library/Developer/Xcode/DerivedData -name "generate_keys" -type f 2>/dev/null | head -1)

if [ -z "$GENERATE_KEYS" ]; then
    echo "Sparkle's generate_keys tool not found in DerivedData."
    echo ""
    echo "Build the project first so SPM resolves Sparkle, then try again:"
    echo "  cd app && xcodegen generate && xcodebuild -scheme Scry -configuration Debug build"
    echo ""
    echo "Or download generate_keys from https://github.com/sparkle-project/Sparkle/releases"
    exit 1
fi

echo "Found generate_keys at: $GENERATE_KEYS"
echo ""

# Generate keys (first run creates and stores in Keychain)
PRIVATE_KEY_FILE=$(mktemp)
rm -f "$PRIVATE_KEY_FILE"
trap 'rm -f "$PRIVATE_KEY_FILE"' EXIT

# Export private key to temp file (suppress stdout)
"$GENERATE_KEYS" -x "$PRIVATE_KEY_FILE" > /dev/null

# Capture public key (suppress the instructional text)
PUBLIC_KEY=$("$GENERATE_KEYS" -p 2>&1 | grep -v "^$" | tail -1)

echo "PUBLIC key:"
echo "  $PUBLIC_KEY"
echo ""
echo "PRIVATE key:"
echo "  $(cat "$PRIVATE_KEY_FILE")"
echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Add the PRIVATE key as a GitHub secret:"
echo "   Name: SPARKLE_EDDSA_KEY"
echo ""
echo "2. Set the PUBLIC key in app/project.yml:"
echo "   SUPublicEDKey: \"$PUBLIC_KEY\""
echo ""
echo "3. Place appcast.xml in site/public/ so it's served at scry.guidotto.dev/appcast.xml"
