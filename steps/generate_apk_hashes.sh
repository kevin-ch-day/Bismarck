#!/bin/bash
# Script: steps/generate_apk_hashes.sh
# Purpose: Generate apk_hashes.csv for a device.
# Usage: generate_apk_hashes.sh --device <id> --out <dir>
# Outputs: <out_dir>/reports/apk_hashes.csv

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/config.sh"
source "$ROOT_DIR/list_devices.sh"
source "$ROOT_DIR/utils/output_utils.sh"
source "$ROOT_DIR/utils/validate_csv.sh"
source "$ROOT_DIR/utils/display/base.sh"
source "$ROOT_DIR/utils/display/status.sh"

DEVICE_ARG=""
OUT_ARG=""

for cmd in adb sha256sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        status_error "Missing required command: $cmd"
        exit 1
    fi
done

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

if [[ -z "$DEVICE_ARG" ]]; then
    status_error "Device argument required (--device)"
    exit 1
fi

DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1

DEVICE_OUT="${OUT_ARG:-$OUTDIR/$DEVICE}"
REPORT_DIR="$DEVICE_OUT/reports"
mkdir -p "$REPORT_DIR"

APK_LIST="$REPORT_DIR/apk_list.csv"
HASH_FILE="$REPORT_DIR/apk_hashes.csv"

if [[ ! -f "$APK_LIST" ]]; then
    status_error "Missing APK list at $APK_LIST"
    exit 1
fi

status_info "Computing SHA-256 hashes for packages on $DEVICE"
write_csv_header "$HASH_FILE" "Package,APK_Path,SHA256"

count=0
while IFS=, read -r pkg apk_path; do
    [[ "$pkg" == "Package" ]] && continue
    hash=$(adb -s "$DEVICE" shell "sha256sum \"$apk_path\"" 2>/dev/null | awk '{print $1}' | tr -d '\r')
    append_csv_row "$HASH_FILE" "$pkg,$apk_path,${hash:-N/A}"
    ((count++))
done < "$APK_LIST"

validate_csv "$HASH_FILE" "Package,APK_Path,SHA256"
status_ok "Wrote hashes for $count packages to $HASH_FILE"
