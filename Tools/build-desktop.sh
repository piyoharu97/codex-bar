#!/bin/zsh
set -eu
cd "${0:A:h}/.."
destination="${CODEX_BAR_OUTPUT:-../Codex bar.app}"
app="$(mktemp -d /private/tmp/codexquota-build.XXXXXX)/Codex bar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" .build/ModuleCache
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macosx14.0" -module-cache-path .build/ModuleCache \
    Shared/Quota.swift Shared/QuotaView.swift Shared/ReleaseVersion.swift App/CodexClient.swift Desktop/*.swift \
    -o ".build/CodexBar-$arch"
done
lipo -create .build/CodexBar-arm64 .build/CodexBar-x86_64 -output "$app/Contents/MacOS/CodexBar"
cp Resources/CodexLogo.png Resources/CodexBarIcon.icns Resources/ChatGPTLogo.png Resources/ChatGPTBarIcon.icns "$app/Contents/Resources/"
/usr/bin/python3 - "$app" "$(cat VERSION)" "$(cat BUILD_NUMBER)" <<'PY'
import sys, plistlib
from pathlib import Path
p=Path(sys.argv[1])/'Contents/Info.plist'
p.write_bytes(plistlib.dumps(dict(CFBundleIdentifier='local.shinya.CodexQuotaDesktop',CFBundleName='Codex bar',CFBundleDisplayName='Codex bar',CFBundleExecutable='CodexBar',CFBundlePackageType='APPL',CFBundleShortVersionString=sys.argv[2],CFBundleVersion=sys.argv[3],CFBundleIconFile='CodexBarIcon.icns',LSMinimumSystemVersion='14.0',LSUIElement=True,NSHighResolutionCapable=True)))
PY
xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
ditto --norsrc --noextattr "$app" "$destination"
echo "完成: $destination"
