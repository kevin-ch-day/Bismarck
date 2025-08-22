#!/bin/bash
# main_menu.sh
# Interactive menu for running Android tool steps

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"
source "$SCRIPT_DIR/utils/display/menu.sh"
source "$SCRIPT_DIR/utils/validate_csv.sh"

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

check_prereqs() {
  for cmd in adb sha256sum; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      status_error "Missing required command: $cmd"
      exit 1
    fi
  done
}

check_prereqs

DEVICE="$(list_devices "$DEVICE_ARG")" || exit 1
OUT_DIR="$OUTDIR/$DEVICE/latest"
mkdir -p "$OUT_DIR"/{apks,raw,reports}

run_step() {
  local script="$1"
  local csv="$2"
  local header="$3"
  shift 3
  status_info "Running $(basename "$script")"
  "$SCRIPT_DIR/$script" --device "$DEVICE" --out "$OUT_DIR" "$@"
  if [[ -n "$csv" && -n "$header" ]]; then
    validate_csv "$csv" "$header" || return 1
  fi
}

while true; do
  clear 2>/dev/null || true
  print_menu "$DEVICE"
  printf "%b" "${CYAN}[?]${RESET} ${BOLD}Select an option:${RESET} "
  read -r choice

  case "$choice" in
    0)
      exit 0
      ;;
    1)
      run_step steps/generate_apk_list.sh "$OUT_DIR/reports/apk_list.csv" "Package,APK_Path"
      ;;
    2)
      run_step find_social_apps.sh "$OUT_DIR/reports/social_apps_found.csv" "Package,APK_Path,InstallType,Detected,Family,Confidence,SHA256,SourceCommand"
      ;;
    3)
      run_step find_motorola_apps.sh "$OUT_DIR/reports/motorola_apps.csv" "Package,APK_Path"
      ;;
    4)
      run_step steps/generate_apk_hashes.sh "$OUT_DIR/reports/apk_hashes.csv" "Package,APK_Path,SHA256"
      ;;
    5)
      run_step steps/generate_apk_metadata.sh "$OUT_DIR/reports/apk_metadata.csv" "Package,Version,MinSDK,TargetSDK,SizeBytes,Permissions"
      ;;
    6)
      run_step steps/generate_running_apps.sh "$OUT_DIR/reports/running_apps.csv" "Package,PID"
      ;;
    7)
      "$SCRIPT_DIR/pull_tiktok_apk.sh" -d "$DEVICE"
      ;;
    8)
      "$SCRIPT_DIR/capture_screenshot.sh" -d "$DEVICE"
      ;;
    9)
      "$SCRIPT_DIR/device_shell.sh" -d "$DEVICE"
      ;;
    10)
      "$SCRIPT_DIR/run.sh" --device "$DEVICE"
      ;;
    11)
      DEVICE="$(list_devices "")" || continue
      OUT_DIR="$OUTDIR/$DEVICE/latest"
      mkdir -p "$OUT_DIR"/{apks,raw,reports}
      ;;
    12)
      if [[ -f "$OUT_DIR/reports/social_apps_found.csv" ]]; then
        ${PAGER:-less} "$OUT_DIR/reports/social_apps_found.csv"
      else
        status_warn "Social report not found"
      fi
      ;;
    13)
      if [[ -f "$OUT_DIR/reports/motorola_apps.csv" ]]; then
        ${PAGER:-less} "$OUT_DIR/reports/motorola_apps.csv"
      else
        status_warn "Motorola report not found"
      fi
      ;;
    *)
      status_error "Invalid option"
      ;;
  esac

  printf "%b" "\n${GRAY}Press Enter to continue...${RESET}"
  read -r

done
