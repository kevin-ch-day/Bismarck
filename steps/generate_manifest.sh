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
HASH_FILE="$DEVICE_OUT/apk_hashes.csv"
RUNNING_FILE="$DEVICE_OUT/running_apps.csv"
SOCIAL_FILE="$DEVICE_OUT/social_apps_found.csv"

TOTAL_PKGS=$(( $(wc -l < "$APK_LIST") -1 ))

# Determine column positions dynamically to avoid stale indices
DETECTED_COL=0
INSTALL_COL=0
if [[ -f "$SOCIAL_FILE" ]]; then
    IFS=',' read -r -a header < "$SOCIAL_FILE"
    for idx in "${!header[@]}"; do
        case "${header[$idx]}" in
            Detected) DETECTED_COL=$((idx+1)) ;;
            InstallType) INSTALL_COL=$((idx+1)) ;;
        esac
    done
fi

if [[ -f "$SOCIAL_FILE" && $DETECTED_COL -gt 0 && $INSTALL_COL -gt 0 ]]; then
    Y_COUNT=$(awk -F, -v d=$DETECTED_COL -v i=$INSTALL_COL 'NR>1 && $d=="Y" && $i=="data"' "$SOCIAL_FILE" | wc -l)
    Q_COUNT=$(awk -F, -v d=$DETECTED_COL -v i=$INSTALL_COL 'NR>1 && $d=="?" && $i=="data"' "$SOCIAL_FILE" | wc -l)
    P_COUNT=$(awk -F, -v d=$DETECTED_COL 'NR>1 && $d=="P"' "$SOCIAL_FILE" | wc -l)
else
    Y_COUNT=0; Q_COUNT=0; P_COUNT=0
fi

cat > "$DEVICE_OUT/manifest.json" <<MANIFEST
{
  "packages_total": $TOTAL_PKGS,
  "social_user_exact": $Y_COUNT,
  "social_user_heuristic": $Q_COUNT,
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
    status_info "Exact user-installed social apps (Y): $Y_COUNT"
    status_info "Heuristic user-installed social apps (?): $Q_COUNT"
    status_info "Preload social components (P): $P_COUNT"
fi
status_info "Log: $(basename "$LOG_FILE")"
status_ok "Manifest written to $DEVICE_OUT/manifest.json"
