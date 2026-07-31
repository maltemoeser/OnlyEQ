#!/bin/bash
# Build a universal release, archive it without breaking framework symlinks,
# and generate the signed Sparkle appcast entry for that version.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: ./scripts/prepare-release.sh VERSION}"
PLIST_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
if [ "$VERSION" != "$PLIST_VERSION" ]; then
    echo "Version mismatch: argument is $VERSION, Info.plist is $PLIST_VERSION" >&2
    exit 1
fi

NOTES="release-notes/$VERSION.md"
if [ ! -f "$NOTES" ]; then
    echo "Missing release notes: $NOTES" >&2
    exit 1
fi

SPARKLE_ROOT=".build/artifacts/sparkle/Sparkle"
GENERATE_APPCAST="$SPARKLE_ROOT/bin/generate_appcast"
GENERATE_KEYS="$SPARKLE_ROOT/bin/generate_keys"
if [ ! -x "$GENERATE_APPCAST" ] || [ ! -x "$GENERATE_KEYS" ]; then
    swift package resolve
fi

# Fail before the expensive build if the signing key is unavailable.
"$GENERATE_KEYS" --account zollans.OnlyEQ.v2 -p >/dev/null
./scripts/build-app.sh release

ARCHIVE="build/OnlyEQ.app.zip"
rm -f "$ARCHIVE"
ditto -c -k --sequesterRsrc --keepParent build/OnlyEQ.app "$ARCHIVE"

APPCAST_WORK="build/appcast-work"
rm -rf "$APPCAST_WORK"
mkdir -p "$APPCAST_WORK"
cp "$ARCHIVE" "$APPCAST_WORK/OnlyEQ.app.zip"
cp "$NOTES" "$APPCAST_WORK/OnlyEQ.app.md"

"$GENERATE_APPCAST" \
    --account zollans.OnlyEQ.v2 \
    --download-url-prefix "https://github.com/zollans/OnlyEQ/releases/download/v$VERSION/" \
    --link "https://github.com/zollans/OnlyEQ" \
    --embed-release-notes \
    --maximum-versions 1 \
    --maximum-deltas 0 \
    "$APPCAST_WORK"

cp "$APPCAST_WORK/appcast-v2.xml" appcast-v2.xml

echo "Prepared OnlyEQ $VERSION"
echo "  Release archive: $ARCHIVE"
echo "  Signed appcast: appcast-v2.xml"
