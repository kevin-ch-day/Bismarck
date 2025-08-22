#!/bin/bash
# Script: find_social_apps.sh
# Purpose: Generate social app report for a connected device.
# Outputs: /output/<device_serial>/social_apps_found.csv

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
HASH_FILE="$DEVICE_OUT/apk_hashes.csv"
SOCIAL_FILE="$DEVICE_OUT/social_apps_found.csv"
SOURCE_CMD="adb -s $DEVICE shell pm list packages -f"

status_info "Scanning for social apps on device: $DEVICE"
status_info "Using APK list: $APK_LIST_FILE"

# Build hash map from apk_hashes.csv
declare -A HASH_MAP
if [[ -f "$HASH_FILE" ]]; then
    while IFS=, read -r pkg sha src; do
        [[ "$pkg" == "Package" ]] && continue
        HASH_MAP[$pkg]="$sha"
    done < "$HASH_FILE"
fi

# Build lookup sets
declare -A EXACT_SET
for pkg in "${SOCIAL_APPS[@]}"; do
    EXACT_SET[$pkg]=1
done
# SOCIAL_PRELOADS associative array already defined in config

get_family() {
    local pkg="$1"
    case "$pkg" in
        com.facebook.*) echo facebook ;;
        com.instagram.*) echo instagram ;;
        com.zhiliaoapp.musically|com.ss.android.ugc.*) echo tiktok ;;
        com.snapchat.android) echo snapchat ;;
        com.twitter.android*) echo twitter ;;
        org.telegram.*) echo telegram ;;
        com.tinder) echo tinder ;;
        tv.twitch.android.app) echo twitch ;;
        com.whatsapp*) echo whatsapp ;;
        com.reddit.frontpage) echo reddit ;;
        com.linkedin.android) echo linkedin ;;
        com.discord) echo discord ;;
        com.google.android.youtube) echo youtube ;;
        *) echo "" ;;
    esac
}

TMP_FILE=$(mktemp)
count=0
exact_count=0
preload_count=0
keyword_count=0
total_scanned=0

while IFS=, read -r pkg apk_path; do
    install="other"
    case "$apk_path" in
        /data/app*) install=data ;;
        /product/*) install=product ;;
        /system/*|/system_ext/*) install=system ;;
        /apex/*) install=apex ;;
        /vendor/*) install=vendor ;;
    esac

    if [[ $pkg == com.android.* || $pkg == com.google.* || $pkg == com.motorola.* ]]; then
        continue
    fi

    ((total_scanned++))

    detected=""
    family=""
    if [[ ${EXACT_SET[$pkg]+_} ]]; then
        detected="Y"
        family=$(get_family "$pkg")
        ((exact_count++))
    elif [[ ${SOCIAL_PRELOADS[$pkg]+_} ]]; then
        detected="P"
        family="${SOCIAL_PRELOADS[$pkg]}"
        ((preload_count++))
    else
        for kw in "${SOCIAL_KEYWORDS[@]}"; do
            if [[ "$pkg" == *"$kw"* ]]; then
                detected="?"
                family="$kw"
                ((keyword_count++))
                break
            fi
        done
    fi

    [[ -z "$detected" ]] && continue

    case "$detected:$install" in
        Y:data) confidence=100 ;;
        \?:data) confidence=70 ;;
        P:product|P:system|P:apex|P:vendor) confidence=20 ;;
        \?:product|\?:system|\?:apex|\?:vendor) confidence=15 ;;
        *) confidence=0 ;;
    esac

    hash="${HASH_MAP[$pkg]:-}"
    append_csv_row "$TMP_FILE" "$pkg,$apk_path,$install,$detected,$family,$confidence,$hash,$SOURCE_CMD"
    ((count++))
    if [[ $detected == "Y" || $detected == "P" ]]; then
        print_detected "$pkg → $apk_path"
    else
        print_unknown "$pkg → $apk_path"
    fi
done < <(tail -n +2 "$APK_LIST_FILE")

if [[ $count -gt 0 ]]; then
    write_csv_header "$SOCIAL_FILE" "Package,APK_Path,InstallType,Detected,Family,Confidence,SHA256,SourceCommand"
    sort -f "$TMP_FILE" >> "$SOCIAL_FILE"
    validate_csv "$SOCIAL_FILE" "Package,APK_Path,InstallType,Detected,Family,Confidence,SHA256,SourceCommand"
    status_ok "Found $count social apps"
    status_info "Exact: $exact_count | Preloaded: $preload_count | Keyword: $keyword_count"
    status_info "Results saved to $SOCIAL_FILE"
    status_info "Report preview:"
    column -t -s, "$SOCIAL_FILE" | head
else
    print_none
fi

status_info "Processed $total_scanned packages (excluding system packages)"

rm -f "$TMP_FILE"

