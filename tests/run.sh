#!/bin/sh
set -eu
: "${LAZARUS_DIR:?Set LAZARUS_DIR to the Lazarus source directory}"
: "${FPC:?Set FPC to the Free Pascal compiler executable}"
: "${DISPLAY:?Run GUI checks on an isolated X display}"
TARGET="$("$FPC" -iTP)-$("$FPC" -iTO)"
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT
cd "$(dirname "$0")/.."
# The component sources: beside this folder, or in MyLazComponents.
PKGS=..
[ -d "$PKGS/LazInk" ] || PKGS=../../MyLazComponents
compile() {
"$FPC" -gl -Cr -Co -Ci -Sa -Fu$PKGS/LazInk -Fu. \
  -Fu$PKGS/FileAss/component/src -Fu$PKGS/FileEye/src -Fu$PKGS/FileEye/src/fpc -Fu$PKGS/InfoBarToast/src \
  -Fu"$LAZARUS_DIR/lcl/units/$TARGET" \
  -Fu"$LAZARUS_DIR/lcl/units/$TARGET/gtk3" \
  -Fu"$LAZARUS_DIR/components/lazutils/lib/$TARGET" \
  -Fu"$LAZARUS_DIR/components/freetype/lib/$TARGET" \
  -FU"$BUILD_DIR" -FE"$BUILD_DIR" "$1" >"$BUILD_DIR/build.log" 2>&1 ||
  { tail -30 "$BUILD_DIR/build.log"; exit 1; }
}
compile tests/source_tests.pas
"$BUILD_DIR/source_tests"
compile $PKGS/LazInk/tests/markdown_roundtrip_tests.pas
if [ -n "${MARKDOWN_SPEC:-}" ]; then "$BUILD_DIR/markdown_roundtrip_tests" "$MARKDOWN_SPEC"
else "$BUILD_DIR/markdown_roundtrip_tests"; fi
compile tests/editor_tests.pas
"$BUILD_DIR/editor_tests" "$@"
