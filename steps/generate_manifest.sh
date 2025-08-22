#!/bin/bash
# Generate manifest.json and run summary for a device
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/output_utils.sh"
source "$SCRIPT_DIR/utils/validate_csv.sh"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"

LOG_FILE=""
DEVICE_ARG=""
OUT_ARG=""
while [[ ${1-} ]]; do
    case "$1" in
        -d|--device)
            DEVICE_ARG="$2"
            shift 2
            ;;
        -l|--log)
            LOG_FILE="$2"
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

DEVICE_OUT="${OUT_ARG:-$OUTDIR/$DEVICE}"
REPORT_DIR="$DEVICE_OUT/reports"
mkdir -p "$REPORT_DIR"
APK_LIST="$REPORT_DIR/apk_list.csv"
META_FILE="$REPORT_DIR/apk_metadata.csv"
HASH_FILE="$REPORT_DIR/apk_hashes.csv"
RUNNING_FILE="$REPORT_DIR/running_apps.csv"
SOCIAL_FILE="$REPORT_DIR/social_apps_found.csv"

TOTAL_PKGS=$(( $(wc -l < "$APK_LIST") -1 ))
if [[ -f "$SOCIAL_FILE" ]]; then
    Y_COUNT=$(awk -F, 'NR>1 && $4=="Y" && $3=="data"' "$SOCIAL_FILE" | wc -l)
    Q_COUNT=$(awk -F, 'NR>1 && $4=="?" && $3=="data"' "$SOCIAL_FILE" | wc -l)
    P_COUNT=$(awk -F, 'NR>1 && $4=="P"' "$SOCIAL_FILE" | wc -l)
else
    Y_COUNT=0; Q_COUNT=0; P_COUNT=0
fi

cat > "$DEVICE_OUT/manifest.json" <<MANIFEST
{
  "packages_total": $TOTAL_PKGS,
  "social_exact_data": $Y_COUNT,
  "social_heuristic_data": $Q_COUNT,
  "social_preload": $P_COUNT,
  "files": {
    "apk_list": "apk_list.csv",
    "apk_metadata": "apk_metadata.csv",
    "apk_hashes": "apk_hashes.csv",
    "running_apps": "running_apps.csv",
    "social_apps": "$( [[ -f "$SOCIAL_FILE" ]] && echo social_apps_found.csv || echo "" )",
    "log": "$(basename "$LOG_FILE")"
  }
}
MANIFEST

status_info "Run Summary"
printf "%-25s %s\n" "apk_list.csv" "$(( $(wc -l < "$APK_LIST") -1 )) rows"
printf "%-25s %s\n" "apk_metadata.csv" "$(( $(wc -l < "$META_FILE") -1 )) rows"
printf "%-25s %s\n" "apk_hashes.csv" "$(( $(wc -l < "$HASH_FILE") -1 )) rows"
printf "%-25s %s\n" "running_apps.csv" "$(( $(wc -l < "$RUNNING_FILE") -1 )) rows"
if [[ -f "$SOCIAL_FILE" ]]; then
    printf "%-25s %s\n" "social_apps_found.csv" "$(( $(wc -l < "$SOCIAL_FILE") -1 )) rows"
    status_info "User-installed social apps (data+Y): $Y_COUNT"
    status_info "Preload social components (P): $P_COUNT"
fi
status_info "Log: $(basename "$LOG_FILE")"
status_ok "Manifest written to $DEVICE_OUT/manifest.json"
