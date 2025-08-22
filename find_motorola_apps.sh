#!/bin/bash
# Script: find_motorola_apps.sh
# Purpose: Generate report of Motorola packages for a connected device.
# Output: /output/<device_serial>/motorola_apps.csv

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/output_utils.sh"
source "$SCRIPT_DIR/utils/validate_csv.sh"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"

DEVICE_ARG=""
while [[ ${1-} ]]; do
    case "$1" in
        -d|--device)
            DEVICE_ARG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1

DEVICE_OUT="$OUTDIR/$DEVICE"
APK_LIST_FILE="$DEVICE_OUT/apk_list.csv"
MOTO_FILE="$DEVICE_OUT/motorola_apps.csv"

status_info "Scanning for Motorola packages on device: $DEVICE"
TMP_FILE=$(mktemp)
count=0

while IFS=, read -r pkg apk_path; do
    [[ "$pkg" == Package ]] && continue
    if [[ $pkg == com.motorola.* ]]; then
        append_csv_row "$TMP_FILE" "$pkg,$apk_path"
        ((count++))
        status_info "Motorola: $pkg → $apk_path"
    fi
done < "$APK_LIST_FILE"

if [[ $count -gt 0 ]]; then
    write_csv_header "$MOTO_FILE" "Package,APK_Path"
    sort -f "$TMP_FILE" >> "$MOTO_FILE"
    validate_csv "$MOTO_FILE" "Package,APK_Path"
    status_ok "Logged $count Motorola packages"
    status_info "Results saved to $MOTO_FILE"
    column -t -s, "$MOTO_FILE" | head
else
    status_warn "No Motorola packages found"
fi

rm -f "$TMP_FILE"
