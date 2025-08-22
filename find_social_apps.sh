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

# Build associative array of package -> pretty name
declare -A SOCIAL_MAP
for entry in "${SOCIAL_APPS[@]}"; do
    pkg="${entry%%:*}"
    name="${entry#*:}"
    SOCIAL_MAP[$pkg]="$name"
done

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

DEVICE=""
DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1

DEVICE_OUT="$OUTDIR/$DEVICE"
mkdir -p "$DEVICE_OUT/apks"
SOCIALFILE="$DEVICE_OUT/social_apps_found.csv"
write_csv_header "$SOCIALFILE" "Package,App_Name,Version,APK_Path,SHA256"

APK_LIST_FILE="$DEVICE_OUT/apk_list.csv"
if [ ! -f "$APK_LIST_FILE" ]; then
    TMP_RAW=$(mktemp)
    adb -s "$DEVICE" shell pm list packages -f -3 2>/dev/null > "$TMP_RAW"
    write_csv_header "$APK_LIST_FILE" "APK_Path,Package"
    awk -F= '{print $1 "," $2}' "$TMP_RAW" | sed 's/^package://g' | sort -t, -k2,2 >> "$APK_LIST_FILE"
    rm -f "$TMP_RAW"
fi

TMP_SOCIAL=$(mktemp)
found=0
while IFS=, read -r APK_PATH PKG; do
    if [[ -n "${SOCIAL_MAP[$PKG]:-}" ]]; then
        NAME="${SOCIAL_MAP[$PKG]}"
        VERSION=$(adb -s "$DEVICE" shell dumpsys package "$PKG" | grep -m1 versionName | awk -F= '{print $2}')
        paths=$(adb -s "$DEVICE" shell pm path "$PKG" 2>/dev/null | sed 's/^package://g')
        while IFS= read -r path; do
            [[ -z "$path" ]] && continue
            hash=$(adb -s "$DEVICE" shell sha256sum "$path" 2>/dev/null | awk '{print $1}')
            append_csv_row "$TMP_SOCIAL" "$PKG,$NAME,${VERSION:-N/A},$path,$hash"
            if [ "$PULL_APKS" = true ]; then
                adb -s "$DEVICE" pull "$path" "$DEVICE_OUT/apks/$(basename "$path")" >/dev/null 2>&1 || true
            fi
        done <<< "$paths"
        print_detected "$NAME ($PKG)"
        found=1
    fi
done < <(tail -n +2 "$APK_LIST_FILE")

sort -t, -k1,1 "$TMP_SOCIAL" >> "$SOCIALFILE"
rm -f "$TMP_SOCIAL"

if [ $found -eq 0 ]; then
    print_none
fi
