#!/bin/zsh
set -eu
cd "${0:A:h}/.."
mkdir -p dist
export CODEX_BAR_OUTPUT="$PWD/dist/Codex bar.app"
./Tools/build-desktop.sh
version="$(cat VERSION)"
archive="Codex-bar-v${version}-universal.zip"
codesign --verify --strict "$CODEX_BAR_OUTPUT"
lipo "$CODEX_BAR_OUTPUT/Contents/MacOS/CodexBar" -verify_arch arm64 x86_64
ditto -c -k --norsrc --noextattr --keepParent "$CODEX_BAR_OUTPUT" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > "$archive.sha256")
echo "配布用ファイル: dist/$archive"
