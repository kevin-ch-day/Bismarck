#!/bin/bash
# Orchestrated full device scan
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"
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

RUN_TS=$(date +%Y%m%d_%H%M%S)
DEVICE_DIR="$OUTDIR/$DEVICE"
DEVICE_OUT="$DEVICE_DIR/$RUN_TS"
mkdir -p "$DEVICE_OUT"/{apks,raw,reports}
ln -sfn "$RUN_TS" "$DEVICE_DIR/latest"

LOG_FILE="$DEVICE_OUT/run.log"
exec > >(tee -a "$LOG_FILE") 2>&1

status_info "Device: $DEVICE"
status_info "Output: $DEVICE_OUT"

run_step() {
    local script="$1"
    local csv="$2"
    local header="$3"
    shift 3
    status_info "Running $(basename "$script")"
    "$script" --device "$DEVICE" --out "$DEVICE_OUT" "$@"
    if [[ -n "$csv" && -n "$header" ]]; then
        validate_csv "$csv" "$header"
    fi
}

run_step "$SCRIPT_DIR/steps/generate_apk_list.sh" \
    "$DEVICE_OUT/reports/apk_list.csv" "Package,APK_Path"
run_step "$SCRIPT_DIR/steps/generate_apk_metadata.sh" \
    "$DEVICE_OUT/reports/apk_metadata.csv" "Package,Version,MinSDK,TargetSDK,SizeBytes,Permissions"
run_step "$SCRIPT_DIR/steps/generate_apk_hashes.sh" \
    "$DEVICE_OUT/reports/apk_hashes.csv" "Package,SHA256,HashSource"
run_step "$SCRIPT_DIR/steps/generate_running_apps.sh" \
    "$DEVICE_OUT/reports/running_apps.csv" "Package,PID"
run_step "$SCRIPT_DIR/find_social_apps.sh" \
    "$DEVICE_OUT/reports/social_apps_found.csv" "Package,APK_Path,InstallType,Detected,Family,Confidence,SHA256,SourceCommand"
run_step "$SCRIPT_DIR/find_motorola_apps.sh" \
    "$DEVICE_OUT/reports/motorola_apps.csv" "Package,APK_Path"
run_step "$SCRIPT_DIR/steps/generate_manifest.sh" "" "" --log "$LOG_FILE"
status_ok "Full scan complete. Reports saved to $DEVICE_OUT"

