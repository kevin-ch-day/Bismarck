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
    mkdir -p "$LOGDIR" "$OUTDIR" "$TMPDIR"
    rm -f "$LOGDIR"/*.log 2>/dev/null

    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    LOGFILE="$LOGDIR/run_$TIMESTAMP.log"
    export LOGFILE
    log_info "Log file initialized at $LOGFILE"
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

    MODEL=$(adb -s "$DEVICE" shell getprop ro.product.model | tr -d '\r')
    MANUFACTURER=$(adb -s "$DEVICE" shell getprop ro.product.manufacturer | tr -d '\r')
    ANDROID_VER=$(adb -s "$DEVICE" shell getprop ro.build.version.release | tr -d '\r')
    SDK=$(adb -s "$DEVICE" shell getprop ro.build.version.sdk | tr -d '\r')

    if declare -f print_device_banner >/dev/null; then
        print_device_banner "$DEVICE" "$MANUFACTURER" "$MODEL" "$ANDROID_VER" "$SDK"
    fi

    log_info "Connected to $DEVICE ($MANUFACTURER $MODEL, Android $ANDROID_VER SDK $SDK)"
}

list_apks() {
    check_device_alive
    log_info "Retrieving APK list..."
    OUTFILE="$OUTDIR/apk_list.csv"

    adb -s "$DEVICE" shell pm list packages -f 2>>"$LOGFILE" > "$TMPDIR/apk_list.raw"
    if [ ! -s "$TMPDIR/apk_list.raw" ]; then
        log_error "Failed to retrieve APK list."
        return 1
    fi

    write_csv_header "$OUTFILE" "APK_Path,Package"
    awk -F'=' '{print $1 "," $2}' "$TMPDIR/apk_list.raw" | sed 's/^package://g' >> "$OUTFILE"
    rm -f "$TMPDIR/apk_list.raw"

    COUNT=$(($(wc -l < "$OUTFILE") - 1))
    log_info "Found $COUNT APKs → $OUTFILE"

    if [ -f "$SCRIPT_DIR/parse_apks.sh" ]; then
        PARSED="$OUTDIR/apk_inventory.csv"
        bash "$SCRIPT_DIR/parse_apks.sh" "$OUTFILE" "$PARSED" >> "$LOGFILE" 2>&1
        log_info "Normalized inventory saved → $PARSED"
    fi
}

filter_social_apps() {
    check_device_alive
    require_file "$OUTDIR/apk_list.csv" || return 1

    SOCIALFILE="$OUTDIR/social_apps.csv"
    log_info "Filtering social media apps..."
    write_csv_header "$SOCIALFILE" "APK_Path,Package"

    for keyword in "${SOCIAL_APPS[@]}"; do
        grep -i "$keyword" "$OUTDIR/apk_list.csv" >> "$SOCIALFILE"
    done

    COUNT=$(($(wc -l < "$SOCIALFILE") - 1))
    if [ $COUNT -gt 0 ]; then
        log_info "Found $COUNT social apps → $SOCIALFILE"
    else
        log_warn "No social media apps found."
        rm -f "$SOCIALFILE"
    fi
}

hash_apks() {
    check_device_alive
    require_file "$OUTDIR/apk_list.csv" || return 1

    MANIFEST="$OUTDIR/apk_hashes.csv"
    log_info "Computing SHA-256 hashes..."
    write_csv_header "$MANIFEST" "Package,APK_Path,SHA256"

    tail -n +2 "$OUTDIR/apk_list.csv" | while IFS=, read -r APK_PATH PKG_NAME; do
        HASH=$(adb -s "$DEVICE" shell sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')
        if [ -n "$HASH" ]; then
            append_csv_row "$MANIFEST" "$PKG_NAME,$APK_PATH,$HASH"
        else
            log_warn "Could not hash $PKG_NAME ($APK_PATH)"
        fi
    done

    log_info "Hash manifest saved → $MANIFEST"
}

apk_metadata() {
    check_device_alive
    require_file "$OUTDIR/apk_list.csv" || return 1

    METADATAFILE="$OUTDIR/apk_metadata.csv"
    log_info "Extracting version & permissions..."
    write_csv_header "$METADATAFILE" "Package,Version,Permissions"

    tail -n +2 "$OUTDIR/apk_list.csv" | while IFS=, read -r APK_PATH PKG_NAME; do
        VERSION=$(adb -s "$DEVICE" shell dumpsys package "$PKG_NAME" | grep -m1 versionName | awk -F= '{print $2}')
        PERMS=$(adb -s "$DEVICE" shell dumpsys package "$PKG_NAME" | grep -E "permission " | awk '{print $1}' | tr '\n' ';')
        append_csv_row "$METADATAFILE" "$PKG_NAME,${VERSION:-N/A},\"$PERMS\""
    done

    log_info "Metadata saved → $METADATAFILE"
}

running_processes() {
    check_device_alive
    require_file "$OUTDIR/apk_list.csv" || return 1

    RUNNINGFILE="$OUTDIR/running_apps.csv"
    log_info "Checking running processes..."
    write_csv_header "$RUNNINGFILE" "Package,PID"

    tail -n +2 "$OUTDIR/apk_list.csv" | while IFS=, read -r APK_PATH PKG_NAME; do
        PID=$(adb -s "$DEVICE" shell pidof "$PKG_NAME" 2>/dev/null)
        [ -n "$PID" ] && append_csv_row "$RUNNINGFILE" "$PKG_NAME,$PID"
    done

    log_info "Running apps list saved → $RUNNINGFILE"
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

        read -p "Select option: " choice
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
    ls -lh "$OUTDIR" | awk '{print $9, $5}'
}

#####################
# MAIN
#####################
check_adb
init_logs
if declare -f print_banner >/dev/null; then
    print_banner
fi
select_device
show_menu
