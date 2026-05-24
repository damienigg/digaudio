#!/usr/bin/env bash
# Local build/run wrapper that bakes a default Subsonic *server URL* (no
# credentials) into the APK via Dart compile-time defines.
#
# Copy this file to `tool/run.sh` (gitignored) and edit the URL/label for your
# own server. Username and password are NEVER baked in — users fill them
# through the Settings screen.
#
# Usage:
#   tool/run.sh build         # → debug APK with the baked URL
#   tool/run.sh run           # → flutter run on a connected device

set -euo pipefail
cd "$(dirname "$0")/.."

SUBSONIC_URL='https://music.example.com'
SUBSONIC_LABEL='My server'

case "${1:-build}" in
  build) flutter build apk --debug \
            --dart-define=SUBSONIC_URL="$SUBSONIC_URL" \
            --dart-define=SUBSONIC_LABEL="$SUBSONIC_LABEL" ;;
  run)   flutter run \
            --dart-define=SUBSONIC_URL="$SUBSONIC_URL" \
            --dart-define=SUBSONIC_LABEL="$SUBSONIC_LABEL" ;;
  *)     echo "usage: $0 build|run" >&2; exit 64 ;;
esac
