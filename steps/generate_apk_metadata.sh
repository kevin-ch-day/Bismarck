#!/bin/bash
# Script: steps/generate_apk_metadata.sh
# Purpose: Generate apk_metadata.csv for a device.
# Usage: generate_apk_metadata.sh --device <id> --out <dir>
# Outputs: <out_dir>/apk_metadata.csv
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
META_FILE="$DEVICE_OUT/apk_metadata.csv"

status_info "Extracting metadata from packages on $DEVICE"
write_csv_header "$META_FILE" "Package,Version,MinSDK,TargetSDK,SizeBytes,Permissions"
count=0
tail -n +2 "$APK_LIST" | while IFS=, read -r pkg apk_path; do
    dump=$(adb -s "$DEVICE" shell dumpsys package "$pkg")
    version=$(awk -F= '/versionName=/{print $2;exit}' <<<"$dump" | tr -d '\r')
    min_sdk=$(awk -F= '/minSdk=/{print $2;exit}' <<<"$dump" | tr -d '\r')
    target_sdk=$(awk -F= '/targetSdk=/{print $2;exit}' <<<"$dump" | tr -d '\r')
    perms=$(awk '/permission/ {print $1}' <<<"$dump" | paste -sd ';' -)
    size=$(adb -s "$DEVICE" shell stat -c %s "$apk_path" 2>/dev/null | tr -d '\r')
    append_csv_row "$META_FILE" "$pkg,${version:-N/A},${min_sdk:-N/A},${target_sdk:-N/A},${size:-N/A},\"${perms}\""
    status_info "Metadata for $pkg captured"
    ((count++))
done

validate_csv "$META_FILE" "Package,Version,MinSDK,TargetSDK,SizeBytes,Permissions"
status_ok "Wrote metadata for $count packages to $META_FILE"
