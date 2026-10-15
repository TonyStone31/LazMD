#!/usr/bin/env bash
# Build the Cocoa application, on a Mac.
#
#   ./build-macos.sh        Debug build; lazmd lands in this directory
#   ./build-macos.sh app    Release, then into dist/: LazMD.app and its zip
#
# Lazarus is looked for in ~/Developer/lazarus; set LAZARUS_DIR for another.
# The project file points at LazInk, FileAss, FileEye and InfoBarToast
# checked out beside this directory.
set -euo pipefail
cd "$(dirname "$0")"
LAZARUS_DIR=${LAZARUS_DIR:-$HOME/Developer/lazarus}
LAZBUILD=${LAZBUILD:-$LAZARUS_DIR/lazbuild}
VERSION=${VERSION:-1.0}
# The oldest macOS the program will start on.  Only 15 has been run.
MIN_MACOS=11.0

if [ "${1:-}" != app ]; then
  exec "$LAZBUILD" --ws=cocoa --opt="-WM$MIN_MACOS" lazmd.lpi
fi

app="dist/LazMD.app"
# first, so a build that fails leaves nothing that looks like its result
rm -rf "$app" dist/icon.iconset dist/lazmd-macos.zip
"$LAZBUILD" --ws=cocoa --opt="-WM$MIN_MACOS -g- -O2 -Xs -XX -CX" lazmd.lpi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" dist/icon.iconset
cp lazmd "$app/Contents/MacOS/"
for size in 16 32 128 256 512; do
  sips -z $size $size icons/lazmd-512.png --out dist/icon.iconset/icon_${size}x${size}.png >/dev/null
done
iconutil -c icns dist/icon.iconset -o "$app/Contents/Resources/lazmd.icns"
rm -rf dist/icon.iconset
cat > "$app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>LazMD</string>
  <key>CFBundleExecutable</key>
  <string>lazmd</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.tonystone31.lazmd</string>
  <key>CFBundleIconFile</key>
  <string>lazmd</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_MACOS</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Markdown document</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>net.daringfireball.markdown</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
EOF
# ditto, not zip: it keeps what Finder expects of an application
ditto -c -k --keepParent "$app" dist/lazmd-macos.zip
ls -la dist/lazmd-macos.zip
