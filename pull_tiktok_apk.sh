#!/usr/bin/env bash
# Pull TikTok APK(s) from an Android device into the current directory.
# Defaults to package: com.zhiliaoapp.musically
# Usage:
#   ./pull_tiktok_apk.sh                # auto-pick one connected device
#   ./pull_tiktok_apk.sh -d SERIAL      # specify device
#   ./pull_tiktok_apk.sh -p PACKAGE     # specify a different package

set -euo pipefail

PKG="com.zhiliaoapp.musically"
DEVICE=""
OUTDIR="."

usage() {
  echo "Usage: $0 [-d SERIAL] [-p PACKAGE] [-o OUTDIR]"
  echo "  -d SERIAL   ADB device serial (auto if exactly one device connected)"
  echo "  -p PACKAGE  Android package name (default: ${PKG})"
  echo "  -o OUTDIR   Output directory (default: current directory)"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d) DEVICE="${2-}"; shift 2 ;;
    -p) PKG="${2-}"; shift 2 ;;
    -o) OUTDIR="${2-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# --- Checks ---
command -v adb >/dev/null 2>&1 || { echo "adb not found in PATH"; exit 2; }
mkdir -p "$OUTDIR"

pick_single_device() {
  adb devices -l | awk 'NR>1 && $2=="device"{print $1}'
}

if [[ -z "$DEVICE" ]]; then
  mapfile -t DEVICES < <(pick_single_device)
  if [[ ${#DEVICES[@]} -eq 1 ]]; then
    DEVICE="${DEVICES[0]}"
  else
    echo "Multiple or zero devices. Use -d SERIAL." >&2
    adb devices -l
    exit 3
  fi
fi

adb -s "$DEVICE" wait-for-device >/dev/null 2>&1 || true
STATE="$(adb -s "$DEVICE" get-state 2>/dev/null || echo unknown)"
if [[ "$STATE" != "device" ]]; then
  echo "Device $DEVICE not ready (state: $STATE)"; exit 4
fi

echo "[*] Device: $DEVICE"
echo "[*] Package: $PKG"

# --- Get APK paths (support splits) ---
# Prefer 'cmd package path', fallback to 'pm path'
get_paths() {
  local cmd_out
  cmd_out="$(adb -s "$DEVICE" shell cmd package path "$PKG" 2>/dev/null || true)"
  if [[ -z "$cmd_out" ]]; then
    cmd_out="$(adb -s "$DEVICE" shell pm path "$PKG" 2>/dev/null || true)"
  fi
  # Lines look like: package:/data/app/.../base.apk
  # Extract after 'package:' and ignore empties.
  awk -F':' '/^package:/{print $2}' <<<"$cmd_out" | sed 's/\r$//' | sed '/^\s*$/d'
}

mapfile -t PATHS < <(get_paths)

if [[ ${#PATHS[@]} -eq 0 ]]; then
  echo "[-] No APK paths found for $PKG (not installed or insufficient permissions)."
  exit 5
fi

echo "[*] Found ${#PATHS[@]} APK path(s):"
for p in "${PATHS[@]}"; do echo "    - $p"; done

# --- Pull APK(s) ---
# Name files predictably in OUTDIR:
#   base.apk           -> <pkg>-base.apk
#   split_config.*.apk -> <pkg>-split_config.*.apk
#   anything_else.apk  -> <pkg>-<basename>.apk
pulled_any="false"
for remote in "${PATHS[@]}"; do
  base="$(basename "$remote")"
  case "$base" in
    base.apk) out="${PKG}-base.apk" ;;
    *.apk)    out="${PKG}-${base}" ;;
    *)        out="${PKG}-${base}.apk" ;;
  esac
  echo "[*] Pulling: $remote -> $OUTDIR/$out"
  if adb -s "$DEVICE" pull "$remote" "$OUTDIR/$out"; then
    pulled_any="true"
  else
    echo "[!] Failed to pull: $remote"
  fi
done

if [[ "$pulled_any" != "true" ]]; then
  echo "[-] Failed to pull any APKs for $PKG."
  exit 6
fi

# --- Optional: show SHA-256 for proof ---
if command -v sha256sum >/dev/null 2>&1; then
  echo "[*] SHA-256 of pulled files:"
  (cd "$OUTDIR" && sha256sum "${PKG}-"*.apk || true)
fi

echo "[+] Done. Files saved in: $OUTDIR"
