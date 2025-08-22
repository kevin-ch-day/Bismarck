#!/bin/bash
# Script: capture_screenshot.sh
# Purpose: Capture a screenshot from the connected device.
# Outputs: <out_dir>/screenshots/screen_TIMESTAMP.png

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
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
        --outdir)
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

DEVICE_OUT="${OUT_ARG:-$OUTDIR/$DEVICE}"
SCREEN_DIR="$DEVICE_OUT/screenshots"
mkdir -p "$SCREEN_DIR"

FILE="$SCREEN_DIR/screen_$(date +%Y%m%d_%H%M%S).png"
status_info "Capturing screenshot to $FILE"
if adb -s "$DEVICE" exec-out screencap -p | tr -d '\r' > "$FILE"; then
    status_ok "Screenshot saved: $FILE"
else
    status_error "Failed to capture screenshot"
    exit 1
fi

