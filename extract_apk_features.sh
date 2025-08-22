#!/bin/bash
# Script: extract_apk_features.sh
# Purpose: Extract static features from a local APK using aapt.
# Usage: extract_apk_features.sh <apk-file> <output-csv>
# Outputs: CSV file with static features at the given path.
set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <apk-file> <output-csv>" >&2
    exit 1
fi

APK="$1"
OUT="$2"

if ! command -v aapt >/dev/null 2>&1; then
    echo "aapt not found; install Android build tools to enable feature extraction" >&2
    exit 2
fi

pkg=$(aapt dump badging "$APK" | awk -F"'" '/package: name=/{print $2}')
verCode=$(aapt dump badging "$APK" | awk -F"'" '/versionCode=/{print $2}')
verName=$(aapt dump badging "$APK" | awk -F"'" '/versionName=/{print $2}')
minSdk=$(aapt dump badging "$APK" | awk -F"'" '/sdkVersion:/{print $2}')
targetSdk=$(aapt dump badging "$APK" | awk -F"'" '/targetSdkVersion:/{print $2}')
perms=$(aapt dump permissions "$APK" | paste -sd ';' -)
size=$(stat -c %s "$APK")

echo "Package,VersionCode,VersionName,MinSDK,TargetSDK,SizeBytes,Permissions" > "$OUT"
echo "$pkg,$verCode,$verName,$minSdk,$targetSdk,$size,\"$perms\"" >> "$OUT"

echo "[+] Static features saved to $OUT"
