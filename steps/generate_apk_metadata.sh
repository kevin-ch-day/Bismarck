#!/bin/bash
# Generate apk_metadata.csv for a device
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
META_FILE="$DEVICE_OUT/apk_metadata.csv"

write_csv_header "$META_FILE" "Package,Version,Permissions"

tail -n +2 "$APK_LIST" | while IFS=, read -r pkg apk_path; do
    version=$(adb -s "$DEVICE" shell dumpsys package "$pkg" | awk -F= '/versionName=/{print $2;exit}' | tr -d '\r')
    perms=$(adb -s "$DEVICE" shell dumpsys package "$pkg" | awk '/permission/ {print $1}' | paste -sd ';' -)
    append_csv_row "$META_FILE" "$pkg,${version:-N/A},\"${perms}\""
done

validate_csv "$META_FILE" "Package,Version,Permissions"
