#!/bin/bash
# Library: apk_actions.sh
# Provides: list_apks, filter_social_apps, hash_apks, apk_metadata, running_processes
# Relies on globals: DEVICE, OUTDIR, TMPDIR, LOGFILE, SCRIPT_DIR, SOCIAL_APPS

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
