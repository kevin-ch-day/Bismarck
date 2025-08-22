#!/bin/bash
# Script: steps/generate_apk_list.sh
# Purpose: Generate apk_list.csv for a device.
# Usage: generate_apk_list.sh --device <id> --out <dir>
# Outputs: <out_dir>/apk_list.csv
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
status_info "Pulling package list from $DEVICE"
write_csv_header "$APK_LIST" "Package,APK_Path"
SOURCE_CMD="adb -s $DEVICE shell pm list packages -f"
$SOURCE_CMD | tr -d '\r' | sed 's/^package://g' | awk -F= '{print $2 "," $1}' | sort -f >> "$APK_LIST"
validate_csv "$APK_LIST" "Package,APK_Path"
status_ok "Saved APK list to $APK_LIST"
