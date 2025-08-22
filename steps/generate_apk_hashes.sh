#!/bin/bash
# Script: steps/generate_apk_hashes.sh
# Purpose: Generate apk_hashes.csv for a device.
# Usage: generate_apk_hashes.sh --device <id> --out <dir>
# Outputs: <out_dir>/apk_hashes.csv
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/output_utils.sh"
source "$SCRIPT_DIR/utils/validate_csv.sh"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"

DEVICE_ARG=""
OUT_ARG=""
while [[ ${1-} ]]; do
    case "$1" in
        -d|--device)
            DEVICE_ARG="$2"
            shift 2
            ;;
        -o|--out)
            OUT_ARG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1

if [[ -z "$OUT_ARG" ]]; then
    status_error "Output directory required (--out)"
    exit 1
fi

DEVICE_OUT="$OUT_ARG"
mkdir -p "$DEVICE_OUT"
APK_LIST="$DEVICE_OUT/apk_list.csv"
HASH_FILE="$DEVICE_OUT/apk_hashes.csv"

status_info "Hashing APKs for $DEVICE"
write_csv_header "$HASH_FILE" "Package,SHA256,HashSource"
count=0
tail -n +2 "$APK_LIST" | while IFS=, read -r pkg apk_path; do
    hash=$(adb -s "$DEVICE" shell sha256sum "$apk_path" 2>/dev/null | awk '{print $1}')
    src=device
    if [[ -z "$hash" ]]; then
        tmp=$(mktemp "$DEVICE_OUT/tmp.XXXXXX")
        if adb -s "$DEVICE" pull "$apk_path" "$tmp" >/dev/null 2>&1; then
            hash=$(sha256sum "$tmp" | awk '{print $1}')
            src=host
        fi
        rm -f "$tmp"
    fi
    append_csv_row "$HASH_FILE" "$pkg,${hash},$src"
    status_info "Hashed $pkg"
    ((count++))
done

validate_csv "$HASH_FILE" "Package,SHA256,HashSource"
status_ok "Wrote $count hashes to $HASH_FILE"
