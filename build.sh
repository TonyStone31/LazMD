#!/usr/bin/env bash
# Release builds of LazMD.
#
#   ./build.sh            Linux (GTK3), zipped into dist/lazmd-linux-x86_64.zip
#   ./build.sh windows    Windows x86_64, cross-built, dist/lazmd-windows-x86_64.zip
#   ./build.sh all        both
#
# lazbuild comes from PATH, or set LAZBUILD (options allowed, for example
# LAZBUILD="$HOME/lazarus/lazbuild --pcp=$HOME/.lazarus").  The project
# file points at LazInk, FileAss, FileEye and InfoBarToast checked out
# beside this directory.  The Mac is build-macos.sh.
set -euo pipefail
cd "$(dirname "$0")"
LAZBUILD=${LAZBUILD:-lazbuild}
# -g- first: the project's debug info makes FPC ignore -Xs; -XX -CX drops unused code
release="-g- -O2 -Xs -XX -CX"

# pack <zip name> <program>: the program, the README and the license
pack() {
  local tmp
  tmp=$(mktemp -d)
  mkdir -p dist
  rm -f "dist/$1"
  cp "$2" README.md LICENSE "$tmp/"
  # debug information stays out of the zip; a stripper that is missing is no reason to stop
  case "$2" in
    *.exe) x86_64-w64-mingw32-strip --strip-all "$tmp/$2" 2>/dev/null || true ;;
    *) strip --strip-all "$tmp/$2" 2>/dev/null || true ;;
  esac
  (cd "$tmp" && zip -q -9 "$OLDPWD/dist/$1" ./*)
  rm -rf "$tmp"
  ls -la "dist/$1"
}

linux() {
  $LAZBUILD --ws=gtk3 --opt="$release" lazmd.lpi
  pack lazmd-linux-x86_64.zip lazmd
}

windows() {
  # --build-all: the LCL and the two packages have to exist for this target
  $LAZBUILD --build-all --os=win64 --cpu=x86_64 --ws=win32 --opt="$release" lazmd.lpi
  pack lazmd-windows-x86_64.zip lazmd.exe
}

case "${1:-linux}" in
  linux) linux ;;
  windows) windows ;;
  all) linux; windows ;;
  *) echo "usage: $0 [linux|windows|all]"; exit 2 ;;
esac
