#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_PATH="$ROOT_DIR/dist/AuroraStudio.app"
CONFIG="release"
SHOULD_NOTARIZE=1
SHOULD_OPEN=1
NOTARY_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-AuroraNotary}"

usage() {
  cat <<'EOF'
Usage: scripts/release_app.sh [options]

Options:
  --debug            Build debug app instead of release.
  --release          Build release app (default).
  --skip-notarize    Build/sign only; skip notarization.
  --no-open          Do not open app after completion.
  --help             Show this help.

Environment:
  NOTARY_KEYCHAIN_PROFILE   notarytool keychain profile name (default: AuroraNotary)
  AURORA_CODESIGN_IDENTITY  optional explicit codesign identity
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      CONFIG="debug"
      ;;
    --release)
      CONFIG="release"
      ;;
    --skip-notarize)
      SHOULD_NOTARIZE=0
      ;;
    --no-open)
      SHOULD_OPEN=0
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

echo "==> Building and signing AuroraStudio.app ($CONFIG)"
"$ROOT_DIR/scripts/build_app.sh" "$CONFIG"

if [[ $SHOULD_NOTARIZE -eq 1 ]]; then
  echo "==> Notarizing app with profile: $NOTARY_PROFILE"
  NOTARY_KEYCHAIN_PROFILE="$NOTARY_PROFILE" "$ROOT_DIR/scripts/notarize-app.sh" "$APP_PATH"
else
  echo "==> Skipping notarization (--skip-notarize)"
fi

if [[ $SHOULD_OPEN -eq 1 ]]; then
  echo "==> Opening app"
  open "$APP_PATH"
fi

echo "Done: $APP_PATH"
