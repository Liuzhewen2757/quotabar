#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
APP="$ROOT/QuotaBar.app"
DIST="$ROOT/dist"

if [[ -n "${VERSION:-}" ]]; then
  version="$VERSION"
else
  version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
fi

if [[ ! -d "$APP" ]]; then
  echo "Missing $APP; run build-app.sh first." >&2
  exit 1
fi

codesign --verify --deep --strict "$APP"

rm -rf "$DIST"
mkdir -p "$DIST"

archive="$DIST/QuotaBar-${version}-macOS-universal.zip"
checksum="$archive.sha256"

# zip from the project directory so the archive has one clean QuotaBar.app
# root and does not contain Finder's __MACOSX metadata directory.
(
  cd "$ROOT"
  /usr/bin/zip -qry -X "$archive" QuotaBar.app
)

/usr/bin/zip -T "$archive" >/dev/null
(
  cd "$DIST"
  /usr/bin/shasum -a 256 "${archive:t}" > "${checksum:t}"
)

echo "Created $archive"
echo "Created $checksum"
