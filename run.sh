#!/bin/bash
# Orchestrate device data collection using step scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/banners.sh"
source "$SCRIPT_DIR/utils/display/menu.sh"
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

setup_logging() {
    DEVICE_OUT="$OUTDIR/$DEVICE"
    mkdir -p "$DEVICE_OUT"
    LOG_FILE="$DEVICE_OUT/run_$(date +%Y%m%d_%H%M%S).log"
    exec > >(tee -a "$LOG_FILE") 2>&1
    status_info "Logs: $LOG_FILE"
}

run_apk_list()      { status_info "Generating APK list"; "$SCRIPT_DIR/steps/generate_apk_list.sh" -d "$DEVICE"; }
run_social_scan()   { status_info "Finding social apps"; "$SCRIPT_DIR/find_social_apps.sh" -d "$DEVICE"; }
run_motorola_scan() { status_info "Listing Motorola apps"; "$SCRIPT_DIR/find_motorola_apps.sh" -d "$DEVICE"; }
run_apk_hashes()    { status_info "Computing APK hashes"; "$SCRIPT_DIR/steps/generate_apk_hashes.sh" -d "$DEVICE"; }
run_apk_metadata()  { status_info "Extracting APK metadata"; "$SCRIPT_DIR/steps/generate_apk_metadata.sh" -d "$DEVICE"; }
run_running_apps()  { status_info "Listing running processes"; "$SCRIPT_DIR/steps/generate_running_apps.sh" -d "$DEVICE"; }
run_pull_tiktok()   { status_info "Pulling TikTok APK"; "$SCRIPT_DIR/pull_tiktok_apk.sh" -d "$DEVICE" -o "$DEVICE_OUT"; }
run_screenshot()    { status_info "Capturing screenshot"; "$SCRIPT_DIR/capture_screenshot.sh" -d "$DEVICE" -o "$DEVICE_OUT"; }
run_shell()         { "$SCRIPT_DIR/device_shell.sh" -d "$DEVICE"; }
view_social_report() {
    local file="$OUTDIR/$DEVICE/social_apps_found.csv"
    if [[ -f "$file" ]]; then
        status_info "Social app report:" && column -t -s, "$file"
    else
        status_warn "No social app report found. Run the scan first."
    fi
}
view_motorola_report() {
    local file="$OUTDIR/$DEVICE/motorola_apps.csv"
    if [[ -f "$file" ]]; then
        status_info "Motorola app report:" && column -t -s, "$file"
    else
        status_warn "No Motorola report found. Run the scan first."
    fi
}
run_full_scan() {
    run_apk_list
    run_apk_metadata
    run_apk_hashes
    run_running_apps
    run_social_scan
    run_motorola_scan
    "$SCRIPT_DIR/steps/generate_manifest.sh" -d "$DEVICE" -l "$LOG_FILE"
    status_ok "Full scan complete. Reports saved to $DEVICE_OUT"
}

switch_device() {
    status_info "Switching device"
    DEVICE=$(list_devices "") || return 1
    adb -s "$DEVICE" wait-for-device >/dev/null 2>&1
    setup_logging
    status_ok "Now using device: $DEVICE"
}

DEVICE=$(list_devices "$DEVICE_ARG") || exit 1
adb -s "$DEVICE" wait-for-device >/dev/null 2>&1
print_banner
status_info "Running on device: $DEVICE"
setup_logging

while true; do
    print_menu
    printf "${BOLD}Select an option:${RESET} "
    read -r choice
    case "$choice" in
        1) run_apk_list ;;
        2) run_social_scan ;;
        3) run_motorola_scan ;;
        4) run_apk_hashes ;;
        5) run_apk_metadata ;;
        6) run_running_apps ;;
        7) run_pull_tiktok ;;
        8) run_screenshot ;;
        9) run_shell ;;
        10) run_full_scan ;;
        11) switch_device ;;
        12) view_social_report ;;
        13) view_motorola_report ;;
        0)
            status_info "Exiting"
            break
            ;;
        *)
            status_warn "Invalid option"
            ;;
    esac
done

