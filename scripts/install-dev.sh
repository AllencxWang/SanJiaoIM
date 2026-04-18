#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build-lexicon.sh"
xcodebuild -project SanJiaoIM.xcodeproj -scheme SanJiaoIM -configuration Debug \
    -derivedDataPath build build

APP="$ROOT/build/Build/Products/Debug/SanJiaoIM.app"
DEST="$HOME/Library/Input Methods/SanJiaoIM.app"

if [ -d "$DEST" ]; then
    echo "Removing existing $DEST"
    rm -rf "$DEST"
fi

cp -R "$APP" "$DEST"
echo "Installed to $DEST. Log out and back in, then enable in System Settings → Keyboard → Input Sources."
