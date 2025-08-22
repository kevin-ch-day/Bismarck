#!/bin/bash
# Script: find_social_apps.sh
# Purpose: Enumerate packages on a device and flag known social apps.
# Outputs manifest to /output/<device_serial>/social_apps_found.csv

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/output_utils.sh"
source "$SCRIPT_DIR/utils/display_utils.sh"

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
mkdir -p "$DEVICE_OUT/apks" "$TMPDIR"
SOCIALFILE="$DEVICE_OUT/social_apps_found.csv"
write_csv_header "$SOCIALFILE" "Package,APK_Path,Detected,SHA256"

TMPLIST="$TMPDIR/${DEVICE}_pkgs.txt"
adb -s "$DEVICE" shell pm list packages -f 2>/dev/null | sed 's/^package://g' > "$TMPLIST"

found=0
while IFS=, read -r APK_PATH PKG; do
    DETECTED="N"
    for s in "${SOCIAL_APPS[@]}"; do
        if [[ "$PKG" == "$s" ]]; then
            DETECTED="Y"
            break
        fi
    done

    if [[ "$DETECTED" == "Y" ]]; then
        hash=$(adb -s "$DEVICE" shell sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')
        append_csv_row "$SOCIALFILE" "$PKG,$APK_PATH,✔,$hash"
        print_detected "$PKG"
        found=1
        if [ "$PULL_APKS" = true ]; then
            adb -s "$DEVICE" pull "$APK_PATH" "$DEVICE_OUT/apks/${PKG}.apk" >/dev/null 2>&1 || true
        fi
    else
        if echo "$PKG" | grep -qi -E 'facebook|instagram|tiktok|snap|twitter|whatsapp|telegram|discord'; then
            hash=$(adb -s "$DEVICE" shell sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')
            append_csv_row "$SOCIALFILE" "$PKG,$APK_PATH,?,$hash"
            print_unknown "$PKG"
            found=1
        fi
    fi

done < <(awk -F'=' '{print $1","$2}' "$TMPLIST")

rm -f "$TMPLIST"

if [ $found -eq 0 ]; then
    print_none
fi
