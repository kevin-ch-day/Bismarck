#!/bin/bash
# Library: apk_actions.sh
# Provides: list_apks, filter_social_apps, hash_apks, apk_metadata, running_processes
# Relies on globals: DEVICE, OUTDIR, LOGFILE, SCRIPT_DIR, SOCIAL_APPS

list_apks() {
    check_device_alive
    log_info "Retrieving APK list..."
    DEVICE_OUT="$OUTDIR/$DEVICE"
    mkdir -p "$DEVICE_OUT"
    OUTFILE="$DEVICE_OUT/apk_list.csv"

    TMP_RAW=$(mktemp)
    adb -s "$DEVICE" shell pm list packages -f -3 2>>"$LOGFILE" > "$TMP_RAW"
    if [ ! -s "$TMP_RAW" ]; then
        log_error "Failed to retrieve APK list."
        rm -f "$TMP_RAW"
        return 1
    fi

    write_csv_header "$OUTFILE" "Package,APK_Path"
    awk -F'=' '{print $2 "," $1}' "$TMP_RAW" | sed 's/^package://g' | sort -t, -k1,1 >> "$OUTFILE"
    rm -f "$TMP_RAW"

    COUNT=$(($(wc -l < "$OUTFILE") - 1))
    log_info "Found $COUNT APKs → $OUTFILE"

    if [ -f "$SCRIPT_DIR/parse_apks.sh" ]; then
        PARSED="$DEVICE_OUT/apk_inventory.csv"
        bash "$SCRIPT_DIR/parse_apks.sh" "$OUTFILE" "$PARSED" >> "$LOGFILE" 2>&1
        log_info "Normalized inventory saved → $PARSED"
    fi
}

filter_social_apps() {
    check_device_alive
    log_info "Filtering social media apps..."

    bash "$SCRIPT_DIR/find_social_apps.sh" --device "$DEVICE" >>"$LOGFILE" 2>&1

    DEVICE_OUT="$OUTDIR/$DEVICE"
    LOCAL_SOCIALFILE="$DEVICE_OUT/social_apps_found.csv"

    if [ -f "$LOCAL_SOCIALFILE" ]; then
        COUNT=$(($(wc -l < "$LOCAL_SOCIALFILE") - 1))
        if [ $COUNT -gt 0 ]; then
            log_info "Found $COUNT social apps → $LOCAL_SOCIALFILE"
        else
            log_warn "No social media apps found."
        fi
    else
        log_warn "Social app scan failed or produced no output."
    fi
}

hash_apks() {
    check_device_alive
    DEVICE_OUT="$OUTDIR/$DEVICE"
    require_file "$DEVICE_OUT/apk_list.csv" || return 1

    MANIFEST="$DEVICE_OUT/apk_hashes.csv"
    log_info "Computing SHA-256 hashes..."
    write_csv_header "$MANIFEST" "Package,APK_Path,SHA256"

    count=0
    while IFS=, read -r PKG_NAME APK_PATH; do
        HASH=$(adb -s "$DEVICE" shell sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')
        if [ -n "$HASH" ]; then
            append_csv_row "$MANIFEST" "$PKG_NAME,$APK_PATH,$HASH"
            ((count++))
        else
            log_warn "Could not hash $PKG_NAME ($APK_PATH)"
        fi
    done < <(tail -n +2 "$DEVICE_OUT/apk_list.csv")

    validate_csv "$MANIFEST" "Package,APK_Path,SHA256"
    log_info "Hashed $count APKs → $MANIFEST"
}

apk_metadata() {
    check_device_alive
    DEVICE_OUT="$OUTDIR/$DEVICE"
    require_file "$DEVICE_OUT/apk_list.csv" || return 1

    METADATAFILE="$DEVICE_OUT/apk_metadata.csv"
    log_info "Extracting version & permissions..."
    write_csv_header "$METADATAFILE" "Package,Version,Permissions"

    count=0
    while IFS=, read -r PKG_NAME APK_PATH; do
        VERSION=$(adb -s "$DEVICE" shell dumpsys package "$PKG_NAME" | grep -m1 versionName | awk -F= '{print $2}')
        PERMS=$(adb -s "$DEVICE" shell dumpsys package "$PKG_NAME" | grep -E "permission " | awk '{print $1}' | tr '\n' ';')
        append_csv_row "$METADATAFILE" "$PKG_NAME,${VERSION:-N/A},\"$PERMS\""
        ((count++))
    done < <(tail -n +2 "$DEVICE_OUT/apk_list.csv")

    validate_csv "$METADATAFILE" "Package,Version,Permissions"
    log_info "Metadata saved for $count packages → $METADATAFILE"
}

running_processes() {
    check_device_alive
    DEVICE_OUT="$OUTDIR/$DEVICE"
    require_file "$DEVICE_OUT/apk_list.csv" || return 1

    RUNNINGFILE="$DEVICE_OUT/running_apps.csv"
    log_info "Checking running processes..."
    write_csv_header "$RUNNINGFILE" "Package,PID"

    count=0
    while IFS=, read -r PKG_NAME APK_PATH; do
        PID=$(adb -s "$DEVICE" shell pidof "$PKG_NAME" 2>/dev/null)
        if [ -n "$PID" ]; then
            append_csv_row "$RUNNINGFILE" "$PKG_NAME,$PID"
            ((count++))
        fi
    done < <(tail -n +2 "$DEVICE_OUT/apk_list.csv")

    validate_csv "$RUNNINGFILE" "Package,PID"
    log_info "Logged $count running apps → $RUNNINGFILE"
}
