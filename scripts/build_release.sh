#!/usr/bin/env bash
# Builds a desktop executable for the specified platform.
# Usage: ./scripts/build_release.sh [windows|linux|macos]
set -e
platform="$1"
if [[ -z "$platform" ]]; then
  echo "Usage: build_release.sh [windows|linux|macos]" >&2
  exit 1
fi
case "$platform" in
  windows|linux|macos)
    flutter build "$platform" --release
    echo "Build complete. Check build/$platform/ for the executable."
    ;;
  *)
    echo "Unsupported platform: $platform" >&2
    exit 1
    ;;
esac

