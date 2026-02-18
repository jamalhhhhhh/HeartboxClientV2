#!/bin/bash
# inject.sh
# Injects a compiled .dylib into a target .ipa file
# Usage: ./inject.sh <path_to.ipa> <path_to.dylib>
# Outputs: patched_<original>.ipa

set -e

IPA="$1"
DYLIB="$2"

if [[ -z "$IPA" || -z "$DYLIB" ]]; then
    echo "Usage: $0 <app.ipa> <tweak.dylib>"
    exit 1
fi

IPA_NAME=$(basename "$IPA" .ipa)
WORK_DIR=$(mktemp -d)
OUTPUT_IPA="patched_${IPA_NAME}.ipa"

echo "[*] Extracting IPA..."
unzip -q "$IPA" -d "$WORK_DIR"

APP_PATH=$(find "$WORK_DIR/Payload" -name "*.app" -maxdepth 1 | head -1)
APP_BINARY=$(defaults read "${APP_PATH}/Info" CFBundleExecutable)
BINARY_PATH="${APP_PATH}/${APP_BINARY}"

echo "[*] App binary: $BINARY_PATH"
echo "[*] Copying dylib into app bundle..."
cp "$DYLIB" "${APP_PATH}/$(basename $DYLIB)"

# ── Use insert_dylib if available, otherwise use optool ──
DYLIB_INSTALL_PATH="@executable_path/$(basename $DYLIB)"

if command -v insert_dylib &>/dev/null; then
    echo "[*] Injecting with insert_dylib..."
    insert_dylib --strip-codesig --inplace "$DYLIB_INSTALL_PATH" "$BINARY_PATH"
elif command -v optool &>/dev/null; then
    echo "[*] Injecting with optool..."
    optool install -c load -p "$DYLIB_INSTALL_PATH" -t "$BINARY_PATH"
else
    echo "[!] Neither insert_dylib nor optool found. Install one and retry."
    exit 1
fi

echo "[*] Re-packaging IPA..."
cd "$WORK_DIR"
zip -qr "${OLDPWD}/${OUTPUT_IPA}" Payload

cd "$OLDPWD"
rm -rf "$WORK_DIR"

echo "[✓] Done! Patched IPA saved as: $OUTPUT_IPA"
