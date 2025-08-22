#!/bin/bash
# Script: parse_apks.sh
# Purpose: Normalize, classify, and enrich APK inventory for Android forensic analysis

INPUT="$1"
OUTPUT="$2"

if [ ! -f "$INPUT" ]; then
    echo "[!] Input file not found: $INPUT"
    exit 1
fi

TMPFILE=$(mktemp)

echo "Package,APK_Path,Source,Type,Category,Flags" > "$TMPFILE"

tail -n +2 "$INPUT" | while IFS=, read -r PKG_NAME APK_PATH; do
    # Skip broken rows
    if [[ -z "$APK_PATH" || -z "$PKG_NAME" ]]; then
        continue
    fi

    CLEAN_PATH="${APK_PATH#package:}"

    ############################
    # SOURCE CLASSIFICATION
    ############################
    if [[ "$CLEAN_PATH" == /system* ]]; then
        SRC="system"
    elif [[ "$CLEAN_PATH" == /product* ]]; then
        SRC="product"
    elif [[ "$CLEAN_PATH" == /vendor* ]]; then
        SRC="vendor"
    elif [[ "$CLEAN_PATH" == /system_ext* ]]; then
        SRC="system_ext"
    elif [[ "$CLEAN_PATH" == /apex* ]]; then
        SRC="apex"
    elif [[ "$CLEAN_PATH" == /data* ]]; then
        SRC="user"
    else
        SRC="other"
    fi

    ############################
    # TYPE CLASSIFICATION
    ############################
    if [[ "$CLEAN_PATH" == *priv-app* ]]; then
        TYPE="priv-app"
    elif [[ "$CLEAN_PATH" == *overlay* ]]; then
        TYPE="overlay"
    elif [[ "$CLEAN_PATH" == *framework* ]]; then
        TYPE="framework"
    elif [[ "$CLEAN_PATH" == *app* ]]; then
        TYPE="app"
    else
        TYPE="unknown"
    fi

    ############################
    # CATEGORY CLASSIFICATION
    ############################
    # Broad classification for SOC/forensic triage
    if [[ "$PKG_NAME" =~ (facebook|instagram|twitter|tiktok|snapchat|telegram|whatsapp|signal) ]]; then
        CATEGORY="social"
    elif [[ "$PKG_NAME" =~ (gmail|email|outlook) ]]; then
        CATEGORY="email"
    elif [[ "$PKG_NAME" =~ (maps|location|gps|nav) ]]; then
        CATEGORY="maps"
    elif [[ "$PKG_NAME" =~ (camera|gallery|photo) ]]; then
        CATEGORY="camera"
    elif [[ "$PKG_NAME" =~ (com.android|org.lineage|com.google.android) ]]; then
        CATEGORY="core"
    else
        CATEGORY="other"
    fi

    ############################
    # FLAGS
    ############################
    FLAGS=()
    [[ "$CLEAN_PATH" == *priv-app* ]] && FLAGS+=("privileged")
    [[ "$CLEAN_PATH" == *overlay* ]] && FLAGS+=("overlay")
    [[ "$SRC" == "user" ]] && FLAGS+=("user-installed")
    [[ "$CATEGORY" == "social" ]] && FLAGS+=("sensitive")
    FLAGSTR=$(IFS=';'; echo "${FLAGS[*]}")

    echo "$PKG_NAME,$CLEAN_PATH,$SRC,$TYPE,$CATEGORY,$FLAGSTR"
done | sort -t, -k1,1 >> "$TMPFILE"

mv "$TMPFILE" "$OUTPUT"

############################
# SUMMARY REPORT
############################
TOTAL=$(($(wc -l < "$OUTPUT") - 1))
SYSTEM=$(grep -c ",system," "$OUTPUT")
VENDOR=$(grep -c ",vendor," "$OUTPUT")
PRODUCT=$(grep -c ",product," "$OUTPUT")
USER=$(grep -c ",user," "$OUTPUT")
SOCIAL=$(grep -c ",social," "$OUTPUT")

echo "[+] Parsed APK list saved to $OUTPUT"
echo "    Total packages : $TOTAL"
echo "    System apps    : $SYSTEM"
echo "    Vendor apps    : $VENDOR"
echo "    Product apps   : $PRODUCT"
echo "    User apps      : $USER"
echo "    Social apps    : $SOCIAL"
