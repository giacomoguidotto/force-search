#!/bin/bash
set -euo pipefail

TAG="${1:?Usage: generate-appcast.sh <tag> <dmg-filename> [ed-signature]}"
DMG="${2:?Usage: generate-appcast.sh <tag> <dmg-filename> [ed-signature]}"
SIGNATURE="${3:-}"

VERSION="${TAG#v}"
DMG_SIZE=$(stat -f%z "$DMG" 2>/dev/null || stat --printf="%s" "$DMG" 2>/dev/null || echo "0")

# Detect repo from git remote
REPO_URL=$(git remote get-url origin 2>/dev/null | sed 's/\.git$//' | sed 's|git@github.com:|https://github.com/|')
DOWNLOAD_URL="${REPO_URL}/releases/download/${TAG}/${DMG}"

mkdir -p site

SIGNATURE_ATTR=""
if [ -n "$SIGNATURE" ]; then
    SIGNATURE_ATTR="sparkle:edSignature=\"${SIGNATURE}\""
fi

cat > site/appcast.xml << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Scry</title>
    <link>${REPO_URL}</link>
    <description>Scry updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <pubDate>$(date -R 2>/dev/null || date -u +"%a, %d %b %Y %H:%M:%S %z")</pubDate>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="${DOWNLOAD_URL}" length="${DMG_SIZE}" type="application/octet-stream" ${SIGNATURE_ATTR}/>
    </item>
  </channel>
</rss>
APPCAST_EOF

echo "Generated site/appcast.xml for ${TAG}"
