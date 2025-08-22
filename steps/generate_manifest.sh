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
SUMMARY_FILE=""
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
        -s|--summary)
            SUMMARY_FILE="$2"
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

if [[ -z "$DEVICE_ARG" ]]; then
    echo "Error: device argument (-d) required" >&2
    exit 1
fi

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

if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$REPORT_DIR/run.log"
fi
if [[ -z "$SUMMARY_FILE" ]]; then
    SUMMARY_FILE="$REPORT_DIR/run_summary.txt"
fi
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$SUMMARY_FILE")"

# Log everything to file and stdout
exec > >(tee -a "$LOG_FILE") 2>&1

LOG_REL=${LOG_FILE#"$DEVICE_OUT/"}
SUMMARY_REL=${SUMMARY_FILE#"$DEVICE_OUT/"}

row_count() { [[ -f "$1" ]] && echo $(( $(wc -l < "$1") -1 )) || echo 0; }

TOTAL_PKGS=$(row_count "$APK_LIST")

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

# Generate manifest.json
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
    "social_apps": $( [[ -f "$SOCIAL_FILE" ]] && echo '"social_apps_found.csv"' || echo null ),
    "log": "$LOG_REL",
    "summary": "$SUMMARY_REL"
  }
}
MANIFEST

# Print run summary
status_info "Run Summary"
{
    printf "%-25s %s\n" "apk_list.csv" "$(row_count "$APK_LIST") rows"
    printf "%-25s %s\n" "apk_metadata.csv" "$(row_count "$META_FILE") rows"
    printf "%-25s %s\n" "apk_hashes.csv" "$(row_count "$HASH_FILE") rows"
    printf "%-25s %s\n" "running_apps.csv" "$(row_count "$RUNNING_FILE") rows"
    if [[ -f "$SOCIAL_FILE" ]]; then
        printf "%-25s %s\n" "social_apps_found.csv" "$(row_count "$SOCIAL_FILE") rows"
    fi
} | tee "$SUMMARY_FILE"

if [[ -f "$SOCIAL_FILE" ]]; then
    status_info "Exact user-installed social apps (Y): $Y_COUNT"
    status_info "Heuristic user-installed social apps (?): $Q_COUNT"
    status_info "Preload social components (P): $P_COUNT"
fi

status_info "Log: $LOG_REL"
status_info "Summary: $SUMMARY_REL"
status_ok "Manifest written to $DEVICE_OUT/manifest.json"
