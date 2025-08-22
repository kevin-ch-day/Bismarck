#!/usr/bin/env bash
# Script: pull_tiktok_apk.sh
# Purpose: Pull TikTok APK(s) from an Android device into the current directory.
# Defaults to package: com.zhiliaoapp.musically
# Usage:
#   ./pull_tiktok_apk.sh                # auto-pick one connected device
#   ./pull_tiktok_apk.sh -d SERIAL      # specify device
#   ./pull_tiktok_apk.sh -p PACKAGE     # specify a different package

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"

PKG="com.zhiliaoapp.musically"
DEVICE=""
OUTDIR="."

usage() {
  echo -e "${BOLD}Usage:${RESET} $0 [-d SERIAL] [-p PACKAGE] [-o OUTDIR]"
  echo -e "  ${YELLOW}-d SERIAL${RESET}   ADB device serial (auto if exactly one device connected)"
  echo -e "  ${YELLOW}-p PACKAGE${RESET}  Android package name (default: ${PKG})"
  echo -e "  ${YELLOW}-o OUTDIR${RESET}   Output directory (default: current directory)"
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
command -v adb >/dev/null 2>&1 || { status_error "adb not found in PATH"; exit 2; }
mkdir -p "$OUTDIR"

pick_single_device() {
  adb devices -l | awk 'NR>1 && $2=="device"{print $1}'
}

if [[ -z "$DEVICE" ]]; then
  mapfile -t DEVICES < <(pick_single_device)
  if [[ ${#DEVICES[@]} -eq 1 ]]; then
    DEVICE="${DEVICES[0]}"
  else
    status_warn "Multiple or zero devices. Use -d SERIAL." >&2
    adb devices -l
    exit 3
  fi
fi

adb -s "$DEVICE" wait-for-device >/dev/null 2>&1 || true
STATE="$(adb -s "$DEVICE" get-state 2>/dev/null || echo unknown)"
if [[ "$STATE" != "device" ]]; then
  echo "Device $DEVICE not ready (state: $STATE)"; exit 4
fi

  status_info "Device: $DEVICE"
  status_info "Package: $PKG"

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
  status_error "No APK paths found for $PKG (not installed or insufficient permissions)."
  exit 5
fi

status_info "Found ${#PATHS[@]} APK path(s):"
for p in "${PATHS[@]}"; do echo -e "    ${CYAN}-${RESET} $p"; done

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
  status_info "Pulling: $remote -> $OUTDIR/$out"
  if adb -s "$DEVICE" pull "$remote" "$OUTDIR/$out"; then
    pulled_any="true"
  else
    status_warn "Failed to pull: $remote"
  fi
done

if [[ "$pulled_any" != "true" ]]; then
  status_error "Failed to pull any APKs for $PKG."
  exit 6
fi

# --- Optional: show SHA-256 for proof ---
if command -v sha256sum >/dev/null 2>&1; then
  status_info "SHA-256 of pulled files:"
  (cd "$OUTDIR" && sha256sum "${PKG}-"*.apk || true)
fi
FEATURE_FILE="$OUTDIR/${PKG}_features.csv"
if command -v aapt >/dev/null 2>&1; then
  first_apk=$(ls "$OUTDIR/${PKG}-"*.apk 2>/dev/null | head -n1)
  if [[ -n "$first_apk" ]]; then
    status_info "Extracting static features"
    "$SCRIPT_DIR/extract_apk_features.sh" "$first_apk" "$FEATURE_FILE" >/dev/null
    status_info "Features saved to $FEATURE_FILE"
    column -t -s, "$FEATURE_FILE"
  fi
else
  status_warn "aapt not found; skipping static feature extraction"
fi

status_ok "Done. Files saved in: $OUTDIR"
