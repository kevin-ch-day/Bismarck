#!/bin/bash
# Generate running_apps.csv for a device
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/output_utils.sh"
source "$SCRIPT_DIR/utils/validate_csv.sh"

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
APK_LIST="$DEVICE_OUT/apk_list.csv"
RUNNING_FILE="$DEVICE_OUT/running_apps.csv"

write_csv_header "$RUNNING_FILE" "Package,PID"

tail -n +2 "$APK_LIST" | while IFS=, read -r pkg _; do
    pid=$(adb -s "$DEVICE" shell pidof "$pkg" 2>/dev/null | tr -d '\r')
    if [[ -n "$pid" ]]; then
        append_csv_row "$RUNNING_FILE" "$pkg,$pid"
    fi
done

validate_csv "$RUNNING_FILE" "Package,PID"
