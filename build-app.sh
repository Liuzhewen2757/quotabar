#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP="$ROOT/QuotaBar.app"
BIN_ARM64="$ROOT/.build/QuotaBar-arm64"
BIN_X86_64="$ROOT/.build/QuotaBar-x86_64"
BIN="$ROOT/.build/QuotaBar"

mkdir -p "$ROOT/.build" "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -target arm64-apple-macos13.0 -parse-as-library \
  -module-cache-path /tmp/quotabar-swift-cache-arm64 \
  -o "$BIN_ARM64" "$ROOT/Sources/QuotaBar/main.swift"
swiftc -target x86_64-apple-macos13.0 -parse-as-library \
  -module-cache-path /tmp/quotabar-swift-cache-x86_64 \
  -o "$BIN_X86_64" "$ROOT/Sources/QuotaBar/main.swift"
lipo -create "$BIN_ARM64" "$BIN_X86_64" -output "$BIN"
cp "$BIN" "$APP/Contents/MacOS/QuotaBar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Codex QuotaBar</string>
    <key>CFBundleDisplayName</key><string>Codex QuotaBar</string>
    <key>CFBundleIdentifier</key><string>local.codex.quotabar.v6</string>
    <key>CFBundleExecutable</key><string>QuotaBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.4.0</string>
    <key>CFBundleVersion</key><string>4</string>
    <key>CFBundleSupportedPlatforms</key><array><string>MacOSX</string></array>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Sign the complete app bundle so Finder and LaunchServices recognize the
# executable after extracting the zip. This is an ad-hoc local signature;
# no developer identity or external service is involved.
codesign --force --deep --sign - "$APP" >/dev/null
codesign --verify --deep --strict "$APP"

echo "Built $APP"
