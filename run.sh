#!/bin/bash
# Script: run.sh
# Purpose: Android APK inventory & analysis toolkit
# Logs -> ./logs | Output -> ./output
# Config from config.sh | Device selection from list_devices.sh

set -o pipefail

#####################
# LOAD CONFIGURATION
#####################
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Core config & device selector
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"

# Utilities (optional—guarded below)
[ -f "$SCRIPT_DIR/utils/logging_utils.sh" ] && source "$SCRIPT_DIR/utils/logging_utils.sh"
[ -f "$SCRIPT_DIR/utils/display_utils.sh" ] && source "$SCRIPT_DIR/utils/display_utils.sh"
[ -f "$SCRIPT_DIR/utils/output_utils.sh" ] && source "$SCRIPT_DIR/utils/output_utils.sh"

# Safe no-op loggers if utils missing
log_info(){ echo "[${TZ:+}$(date '+%F %T')] [INFO] $*"; }
log_warn(){ echo "[${TZ:+}$(date '+%F %T')] [WARN] $*"; }
log_error(){ echo "[${TZ:+}$(date '+%F %T')] [ERROR] $*" >&2; }
log_debug(){ [ "${DEBUG_MODE:-0}" -eq 1 ] && echo "[${TZ:+}$(date '+%F %T')] [DEBUG] $*"; }

write_csv_header(){ echo "$2" > "$1"; }
append_csv_row(){ echo "$2" >> "$1"; }
require_file(){ [ -f "$1" ] || { log_error "Required file missing: $1"; return 1; }; }

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
<<<<<<< HEAD
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
=======
  mkdir -p "$LOGDIR" "$OUTDIR" "$TMPDIR"
  rm -f "$LOGDIR"/*.log 2>/dev/null
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  LOGFILE="$LOGDIR/run_$TIMESTAMP.log"
  export LOGFILE
  log_info "Log file initialized at $LOGFILE"
>>>>>>> 73f4566 (Sync)
}

# Single ADB wrapper: always pin to device, wait, and log
adb_s() {
  local rc
  if [ -z "${DEVICE:-}" ]; then
    log_error "adb_s called before DEVICE is set"; return 2
  fi
  # Make sure server is up, and device is ready
  adb start-server >/dev/null 2>&1
  adb -s "$DEVICE" wait-for-device >/dev/null 2>&1
  log_debug "adb -s $DEVICE $*"
  # Send stderr to log, stdout to caller
  adb -s "$DEVICE" "$@" 2>>"$LOGFILE"
  rc=$?
  if [ $rc -ne 0 ]; then
    log_warn "ADB command failed (rc=$rc): adb -s $DEVICE $*"
    # Tail last few lines of log for quick triage
    tail -n 5 "$LOGFILE" | sed 's/^/[adb-stderr] /'
  fi
  return $rc
}

check_device_alive() {
  adb_s get-state >/dev/null || { log_error "Device $DEVICE disconnected."; exit 1; }
}

trap 'log_warn "Interrupted."; exit 130' INT

#####################
# CORE FUNCTIONS
#####################
select_device() {
  # list_devices must print ONLY the chosen serial to stdout
  DEVICE="$(list_devices)"
  if [ -z "$DEVICE" ]; then
    log_error "Device selection failed."
    exit 1
  fi

  # Per-device output dir
  OUTDEV="$OUTDIR/$DEVICE"
  mkdir -p "$OUTDEV" "$OUTDEV/apks" "$TMPDIR"

  # Warm up device & fetch info
  MODEL=$(adb_s shell getprop ro.product.model | tr -d '\r')
  MANUFACTURER=$(adb_s shell getprop ro.product.manufacturer | tr -d '\r')
  ANDROID_VER=$(adb_s shell getprop ro.build.version.release | tr -d '\r')
  SDK=$(adb_s shell getprop ro.build.version.sdk | tr -d '\r')

  if declare -f print_device_banner >/dev/null; then
    print_device_banner "$DEVICE" "$MANUFACTURER" "$MODEL" "$ANDROID_VER" "$SDK"
  else
    echo "Connected to $DEVICE ($MANUFACTURER $MODEL, Android $ANDROID_VER SDK $SDK)"
  fi

  log_info "Connected to $DEVICE ($MANUFACTURER $MODEL, Android $ANDROID_VER SDK $SDK)"
}

list_apks() {
  check_device_alive
  log_info "Retrieving APK list..."
  local raw="$TMPDIR/${DEVICE}_apk_list.raw"
  local out="$OUTDEV/apk_list.csv"

  adb_s shell pm list packages -f > "$raw"
  if [ ! -s "$raw" ]; then
    log_error "Failed to retrieve APK list (empty output)."
    return 1
  fi

  write_csv_header "$out" "APK_Path,Package"
  awk -F'=' '{print $1 "," $2}' "$raw" | sed 's/^package://g' >> "$out"
  rm -f "$raw"

  local count=$(( $(wc -l < "$out") - 1 ))
  log_info "Found $count APKs → $out"

  # Auto-normalize if available
  if [ -f "$SCRIPT_DIR/parse_apks.sh" ]; then
    local parsed="$OUTDEV/apk_inventory.csv"
    bash "$SCRIPT_DIR/parse_apks.sh" "$out" "$parsed" >> "$LOGFILE" 2>&1
    log_info "Normalized inventory saved → $parsed"
  fi
}

filter_social_apps() {
  check_device_alive
  local list="$OUTDEV/apk_list.csv"
  require_file "$list" || return 1

  local social="$OUTDEV/social_apps_found.csv"
  log_info "Filtering social media apps…"
  write_csv_header "$social" "APK_Path,Package,Label"

  # Use SOCIAL_APPS mapping or keywords
  # Support both "pkg:Label" and bare keywords (back-compat)
  for token in "${SOCIAL_APPS[@]}"; do
    if [[ "$token" == *:* ]]; then
      pkg="${token%%:*}"
      label="$(echo "${token#*:}" | xargs)"
      grep -i ",$pkg\$" "$list" | awk -F',' -v L="$label" '{print $1","$2","L}' >> "$social"
    else
      # keyword heuristic match
      grep -i "$token" "$list" | awk -F',' -v L="$token" '{print $1","$2","L}' >> "$social"
    fi
  done

  # De-duplicate
  if [ -s "$social" ]; then
    tmp="$social.tmp"; mv "$social" "$tmp"
    awk -F',' '!seen[$2]++' "$tmp" > "$social"
    rm -f "$tmp"
  fi

  local count=$(( $(wc -l < "$social") - 1 ))
  if [ $count -gt 0 ]; then
    log_info "Found $count social apps → $social"
  else
    log_warn "No social media apps found."
    rm -f "$social"
  fi
}

hash_apks() {
  check_device_alive
  local list="$OUTDEV/apk_list.csv"
  require_file "$list" || return 1

  local manifest="$OUTDEV/apk_hashes.csv"
  log_info "Computing SHA-256 hashes..."
  write_csv_header "$manifest" "Package,APK_Path,SHA256"

  tail -n +2 "$list" | while IFS=, read -r APK_PATH PKG_NAME; do
    HASH=$(adb_s shell sha256sum "$APK_PATH" 2>/dev/null | awk '{print $1}')
    if [ -n "$HASH" ]; then
      append_csv_row "$manifest" "$PKG_NAME,$APK_PATH,$HASH"
    else
      log_warn "Could not hash $PKG_NAME ($APK_PATH)"
    fi
  done

  log_info "Hash manifest saved → $manifest"
}

apk_metadata() {
  check_device_alive
  local list="$OUTDEV/apk_list.csv"
  require_file "$list" || return 1

  local meta="$OUTDEV/apk_metadata.csv"
  log_info "Extracting version & permissions..."
  write_csv_header "$meta" "Package,Version,Permissions"

  tail -n +2 "$list" | while IFS=, read -r APK_PATH PKG_NAME; do
    VERSION=$(adb_s shell dumpsys package "$PKG_NAME" | grep -m1 versionName | awk -F= '{print $2}')
    PERMS=$(adb_s shell dumpsys package "$PKG_NAME" | grep -E "permission " | awk '{print $1}' | tr '\n' ';')
    append_csv_row "$meta" "$PKG_NAME,${VERSION:-N/A},\"$PERMS\""
  done

  log_info "Metadata saved → $meta"
}

running_processes() {
  check_device_alive
  local list="$OUTDEV/apk_list.csv"
  require_file "$list" || return 1

  local running="$OUTDEV/running_apps.csv"
  log_info "Checking running processes..."
  write_csv_header "$running" "Package,PID"

  tail -n +2 "$list" | while IFS=, read -r APK_PATH PKG_NAME; do
    PID=$(adb_s shell pidof "$PKG_NAME" 2>/dev/null)
    [ -n "$PID" ] && append_csv_row "$running" "$PKG_NAME,$PID"
  done

  log_info "Running apps list saved → $running"
}

#####################
# MENU & SUMMARY
#####################
summary() {
  echo ""
  if declare -f print_section >/dev/null; then
    print_section "Run Summary"
  else
    echo "===== Run Summary ====="
  fi
  ls -lh "$OUTDEV" | awk '{print $9, $5}'
}

<<<<<<< HEAD
summary() {
    echo ""
    print_section "Run Summary"
    find "$OUTDIR" -type f -printf '%P %s\n' | numfmt --to=iec --field=2
=======
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
>>>>>>> 73f4566 (Sync)
}

#####################
# MAIN
#####################
check_adb
init_logs
if declare -f print_banner >/dev/null; then print_banner; fi
select_device
show_menu
