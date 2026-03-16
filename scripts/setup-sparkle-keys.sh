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

# Generate keys
"$GENERATE_KEYS"

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Copy the PRIVATE key and add it as a GitHub secret:"
echo "   Name: SPARKLE_EDDSA_KEY"
echo "   Value: (the private key output above)"
echo ""
echo "2. Copy the PUBLIC key and set it in app/project.yml:"
echo "   SUPublicEDKey: \"<your-public-key>\""
echo ""
echo "3. Enable GitHub Pages on the 'gh-pages' branch for your repo."
echo ""
