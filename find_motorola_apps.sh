#!/bin/bash
# Script: find_motorola_apps.sh
# Purpose: Generate report of Motorola packages for a connected device.
# Output: <out_dir>/motorola_apps.csv

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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

if [[ -z "$DEVICE_ARG" ]]; then
    status_error "Device argument required (--device)"
    exit 1
fi

DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1

# Resolve output directory
if [[ -n "$OUT_ARG" ]]; then
    DEVICE_OUT="$OUT_ARG"
else
    DEVICE_OUT="$OUTDIR/$DEVICE/reports"
fi
mkdir -p "$DEVICE_OUT"

APK_LIST_FILE="$DEVICE_OUT/apk_list.csv"
MOTO_FILE="$DEVICE_OUT/motorola_apps.csv"

status_info "Scanning for Motorola packages on device: $DEVICE"
TMP_FILE=$(mktemp "$DEVICE_OUT/tmp.XXXXXX")
count=0

while IFS=, read -r pkg apk_path; do
    [[ "$pkg" == Package ]] && continue
    if [[ $pkg == com.motorola.* ]]; then
        append_csv_row "$TMP_FILE" "$pkg,$apk_path"
        ((count++))
        status_info "Motorola: $pkg → $apk_path"
    fi
done < "$APK_LIST_FILE"

write_csv_header "$MOTO_FILE" "Package,APK_Path"
if [[ $count -gt 0 ]]; then
    sort -f "$TMP_FILE" >> "$MOTO_FILE"
    status_ok "Logged $count Motorola packages"
    status_info "Results saved to $MOTO_FILE"
    column -t -s, "$MOTO_FILE" | head
else
    status_warn "No Motorola packages found"
fi

validate_csv "$MOTO_FILE" "Package,APK_Path"
rm -f "$TMP_FILE"
