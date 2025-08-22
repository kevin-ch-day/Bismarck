#!/bin/bash
# Script: run.sh
# Purpose: Android APK inventory & analysis toolkit
# Logs -> ./logs | Output -> ./output
# Config from config.sh | Device selection from list_devices.sh

#####################
# LOAD CONFIGURATION
#####################
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Core config & device selector
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"

# Utilities
source "$SCRIPT_DIR/utils/logging_utils.sh"
source "$SCRIPT_DIR/utils/display_utils.sh"
source "$SCRIPT_DIR/utils/output_utils.sh"

# APK actions
source "$SCRIPT_DIR/apk_actions.sh"

#####################
# INITIALIZATION
#####################
check_adb() {
    if ! command -v adb &> /dev/null; then
        log_error "adb not found. Install Android platform-tools."
        exit 1
    fi
}

init_logs() {
    mkdir -p "$LOGDIR" "$OUTDIR"
    rm -f "$LOGDIR"/*.log 2>/dev/null

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOGFILE="$LOGDIR/run_$TIMESTAMP.log"
    export LOGFILE

    # collect any adb server logs
    if [ -d "$PROJECT_ROOT/tmp" ]; then
        mv "$PROJECT_ROOT"/tmp/adb*.log "$LOGDIR"/ 2>/dev/null || true
        rm -rf "$PROJECT_ROOT/tmp"
    fi
    ADB_LOG="/tmp/adb.$(id -u).log"
    if [ -f "$ADB_LOG" ]; then
        mv "$ADB_LOG" "$LOGDIR/adb_$TIMESTAMP.log" 2>/dev/null || true
    fi

    log_info "Log file initialized at $LOGFILE"
}

reset_adb() {
    adb kill-server >/dev/null 2>&1
    adb start-server >/dev/null 2>&1
    adb wait-for-device >/dev/null 2>&1
}

check_device_alive() {
    if ! adb -s "$DEVICE" get-state 1>/dev/null 2>&1; then
        log_error "Device $DEVICE disconnected."
        exit 1
    fi
}

#####################
# CORE FUNCTIONS
#####################
select_device() {
    DEVICE=$(list_devices)
    if [ -z "$DEVICE" ]; then
        log_error "Device selection failed."
        exit 1
    fi

    adb -s "$DEVICE" wait-for-device >/dev/null 2>&1
    if ! adb -s "$DEVICE" get-state 1>/dev/null 2>&1; then
        log_error "Device $DEVICE not ready."
        exit 1
    fi

    MODEL=$(adb -s "$DEVICE" shell getprop ro.product.model | tr -d '\r')
    MANUFACTURER=$(adb -s "$DEVICE" shell getprop ro.product.manufacturer | tr -d '\r')
    ANDROID_VER=$(adb -s "$DEVICE" shell getprop ro.build.version.release | tr -d '\r')
    SDK=$(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')

    if declare -f print_device_banner >/dev/null; then
        print_device_banner "$DEVICE" "$MANUFACTURER" "$MODEL" "$ANDROID_VER" "$SDK"
    fi

    log_info "Connected to $DEVICE ($MANUFACTURER $MODEL, Android $ANDROID_VER SDK $SDK)"
}

#####################
# MENU & SUMMARY
#####################
show_menu() {
    while true; do
        if declare -f print_menu >/dev/null; then
            print_menu
        else
            echo "===== Android Tool Menu ====="
            echo "1) List all APKs"
            echo "2) Filter social apps"
            echo "3) Compute SHA-256 hashes"
            echo "4) Extract APK metadata"
            echo "5) Show running processes"
            echo "6) Run all"
            echo "0) Exit"
        fi

        read -r -p "Select option: " choice
        case $choice in
            1) list_apks ;;
            2) filter_social_apps ;;
            3) hash_apks ;;
            4) apk_metadata ;;
            5) running_processes ;;
            6) list_apks; filter_social_apps; hash_apks; apk_metadata; running_processes; summary ;;
            0) log_info "Exiting."; break ;;
            *) log_warn "Invalid choice." ;;
        esac
    done
}

summary() {
    echo ""
    print_section "Run Summary"
    find "$OUTDIR" -type f -printf '%P %s\n' | numfmt --to=iec --field=2
}

#####################
# MAIN
#####################
check_adb
init_logs
reset_adb
if declare -f print_banner >/dev/null; then
    print_banner
fi
select_device
show_menu
