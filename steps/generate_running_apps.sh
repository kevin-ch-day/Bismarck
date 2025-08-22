#!/bin/bash
# Script: steps/generate_running_apps.sh
# Purpose: Generate running_apps.csv for a device.
# Usage: generate_running_apps.sh --device <id> --out <dir>
# Outputs: <out_dir>/reports/running_apps.csv
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

# Default to reports subdir for consistency
DEVICE_OUT="${OUT_ARG:-$OUTDIR/$DEVICE}"
REPORT_DIR="$DEVICE_OUT/reports"
mkdir -p "$REPORT_DIR"

APK_LIST="$REPORT_DIR/apk_list.csv"
RUNNING_FILE="$REPORT_DIR/running_apps.csv"

status_info "Checking running processes on $DEVICE"
write_csv_header "$RUNNING_FILE" "Package,PID"
count=0
while IFS=, read -r pkg _; do
    pid=$(adb -s "$DEVICE" shell pidof "$pkg" 2>/dev/null | tr -d '\r')
    if [[ -n "$pid" ]]; then
        append_csv_row "$RUNNING_FILE" "$pkg,$pid"
        status_info "$pkg is running (PID $pid)"
        ((count++))
    fi
done < <(tail -n +2 "$APK_LIST")

validate_csv "$RUNNING_FILE" "Package,PID"
status_ok "Logged $count running packages to $RUNNING_FILE"
