#!/bin/bash
# run.sh
# Entry point: perform environment checks then either launch the interactive
# menu or orchestrate a full device scan

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"
source "$SCRIPT_DIR/utils/validate_csv.sh"
source "$SCRIPT_DIR/utils/device_utils.sh"

usage() {
    echo "Usage: $0 [-d DEVICE] [--menu]" >&2
    exit 1
}

check_prereqs() {
    for cmd in adb sha256sum; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            status_error "Missing required command: $cmd"
            exit 1
        fi
    done
}

DEVICE_ARG=""
MENU=false
while [[ ${1-} ]]; do
    case "$1" in
        -d|--device)
            DEVICE_ARG="$2"
            shift 2
            ;;
        -m|--menu)
            MENU=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            shift
            ;;
    esac
done

check_prereqs

# Default to menu if no device was supplied
if $MENU || [[ -z "$DEVICE_ARG" ]]; then
    if [[ -n "$DEVICE_ARG" ]]; then
        "$SCRIPT_DIR/main_menu.sh" --device "$DEVICE_ARG"
    else
        "$SCRIPT_DIR/main_menu.sh"
    fi
    exit $?
fi

DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1
ensure_device_state "$DEVICE"

# Timestamped run directory
RUN_TS=$(date +%Y%m%d_%H%M%S)
DEVICE_DIR="$OUTDIR/$DEVICE"
DEVICE_OUT="$DEVICE_DIR/$RUN_TS"
mkdir -p "$DEVICE_OUT"/{apks,raw,reports}
ln -sfn "$RUN_TS" "$DEVICE_DIR/latest"

LOG_FILE="$DEVICE_OUT/reports/run.log"
SUMMARY_FILE="$DEVICE_OUT/reports/run_summary.txt"

# Log everything to file and stdout
exec > >(tee -a "$LOG_FILE") 2>&1

status_info "Device: $DEVICE"
status_info "Output: $DEVICE_OUT"
status_info "Logs: $LOG_FILE"
status_info "Summary: $SUMMARY_FILE"

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

# Steps
run_step "$SCRIPT_DIR/steps/generate_apk_list.sh" \
    "$DEVICE_OUT/reports/apk_list.csv" "Package,APK_Path"

run_step "$SCRIPT_DIR/steps/generate_apk_metadata.sh" \
    "$DEVICE_OUT/reports/apk_metadata.csv" "Package,Version,MinSDK,TargetSDK,SizeBytes,Permissions"

run_step "$SCRIPT_DIR/steps/generate_apk_hashes.sh" \
    "$DEVICE_OUT/reports/apk_hashes.csv" "Package,APK_Path,SHA256"

run_step "$SCRIPT_DIR/steps/generate_running_apps.sh" \
    "$DEVICE_OUT/reports/running_apps.csv" "Package,PID"

run_step "$SCRIPT_DIR/find_social_apps.sh" \
    "$DEVICE_OUT/reports/social_apps_found.csv" "Package,APK_Path,InstallType,Detected,Family,Confidence,SHA256,SourceCommand"

run_step "$SCRIPT_DIR/find_motorola_apps.sh" \
    "$DEVICE_OUT/reports/motorola_apps.csv" "Package,APK_Path"

run_step "$SCRIPT_DIR/steps/generate_manifest.sh" "" "" --log "$LOG_FILE" --summary "$SUMMARY_FILE"

status_ok "Full scan complete. Reports saved to $DEVICE_OUT"
