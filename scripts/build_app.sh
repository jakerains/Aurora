#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG="${1:-debug}"
APP_NAME="AuroraStudio"
APP_DIR="$ROOT_DIR/dist/${APP_NAME}.app"
APP_ICON="$ROOT_DIR/Sources/AuroraStudioApp/Resources/AppIcon.icns"

resolve_signing_identity() {
  if [[ -n "${AURORA_CODESIGN_IDENTITY:-}" ]]; then
    echo "$AURORA_CODESIGN_IDENTITY"
    return
  fi

  local detected
  detected="$( (security find-identity -v -p codesigning 2>/dev/null || true) | awk -F'"' '/Developer ID Application:/ { print $2; exit }')"
  if [[ -n "$detected" ]]; then
    echo "$detected"
    return
  fi

  echo "-"
}

sign_item() {
  local path="$1"
  local identity="$2"
  if [[ "$identity" == "-" ]]; then
    codesign --force --sign - "$path" >/dev/null
  else
    codesign --force --timestamp --options runtime --sign "$identity" "$path" >/dev/null
  fi
}

swift build -c "$CONFIG" >/dev/null
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"

if compgen -G "$BIN_DIR/*.bundle" > /dev/null; then
  cp -R "$BIN_DIR"/*.bundle "$APP_DIR/Contents/Resources/"
fi

if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.aurorastudio.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>26.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

SIGN_IDENTITY="$(resolve_signing_identity)"
echo "Signing identity: $SIGN_IDENTITY"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Warning: no Developer ID identity detected; using ad-hoc signing."
fi

if [[ -d "$APP_DIR/Contents/Resources" ]]; then
  while IFS= read -r bundle; do
    sign_item "$bundle" "$SIGN_IDENTITY"
  done < <(find "$APP_DIR/Contents/Resources" -type d -name "*.bundle" | sort)
fi

sign_item "$APP_DIR/Contents/MacOS/$APP_NAME" "$SIGN_IDENTITY"
sign_item "$APP_DIR" "$SIGN_IDENTITY"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
if ! spctl -a -t exec -vv "$APP_DIR" >/dev/null 2>&1; then
  echo "spctl check is not fully passing yet (expected before notarization)."
fi

echo "Built app bundle: $APP_DIR"
echo "Open it with: open '$APP_DIR'"
