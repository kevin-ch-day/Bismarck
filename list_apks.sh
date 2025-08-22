#!/bin/bash
# Library: list_apks.sh
# Purpose: Provide a function to retrieve APK inventory from connected Android device
# Usage: Source this script inside run.sh, then call list_apks

list_apks() {
    local DEVICE="$1"
    local OUTDIR="$2"
    local LOGFILE="$3"
    local SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    local TMPDIR="$OUTDIR/tmp"

    mkdir -p "$OUTDIR" "$TMPDIR"

    local OUTFILE="$OUTDIR/apk_list.csv"

    echo "[*] Retrieving APK list from $DEVICE..." | tee -a "$LOGFILE"

    adb -s "$DEVICE" shell pm list packages -f 2>>"$LOGFILE" > "$TMPDIR/apk_list.raw"
    if [ ! -s "$TMPDIR/apk_list.raw" ]; then
        echo "[!] Failed to retrieve APK list from $DEVICE" | tee -a "$LOGFILE"
        return 1
    fi

    # Normalize into CSV
    echo "APK_Path,Package" > "$OUTFILE"
    awk -F'=' '{print $1 "," $2}' "$TMPDIR/apk_list.raw" | sed 's/^package://g' >> "$OUTFILE"
    rm -f "$TMPDIR/apk_list.raw"

    local COUNT=$(($(wc -l < "$OUTFILE") - 1))
    echo "[+] Found $COUNT APKs. Saved list to $OUTFILE" | tee -a "$LOGFILE"

    # Auto-normalize with parse_apks.sh if present
    if [ -f "$SCRIPT_DIR/parse_apks.sh" ]; then
        local PARSED="$OUTDIR/apk_inventory.csv"
        bash "$SCRIPT_DIR/parse_apks.sh" "$OUTFILE" "$PARSED" | tee -a "$LOGFILE"
    fi

    # Return path to CSV for callers
    echo "$OUTFILE"
}
