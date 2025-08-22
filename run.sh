#!/bin/bash
# Integrated Android APK inventory pipeline
# Generates per-run output with a single master apps inventory CSV

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/list_devices.sh"
# shellcheck source=utils/output_utils.sh
[ -f "$SCRIPT_DIR/utils/output_utils.sh" ] && source "$SCRIPT_DIR/utils/output_utils.sh"
# shellcheck source=utils/logging_utils.sh
[ -f "$SCRIPT_DIR/utils/logging_utils.sh" ] && source "$SCRIPT_DIR/utils/logging_utils.sh"

# Fallback logging helpers if library missing
log_info(){ echo "[${TZ:+}$(date '+%F %T')] [INFO] $*"; }
log_warn(){ echo "[${TZ:+}$(date '+%F %T')] [WARN] $*"; }
log_error(){ echo "[${TZ:+}$(date '+%F %T')] [ERROR] $*" >&2; }

#####################
# ARGUMENT PARSING
#####################
PRESELECT=""
NON_INTERACTIVE=0 # parsed but currently no interactive menu
while [[ ${1-} ]]; do
  case "$1" in
    -d|--device) PRESELECT="$2"; shift 2;;
    --non-interactive) NON_INTERACTIVE=1; shift;;
    *) shift;;
  esac
done

#####################
# DEVICE SELECTION & HEALTH
#####################
check_adb(){ command -v adb >/dev/null || { log_error "adb not found"; exit 1; }; }

select_device(){
  DEVICE=$(list_devices "$PRESELECT") || true
  if [[ -z "${DEVICE:-}" ]]; then
    log_error "No device selected"; exit 1
  fi
  echo "$DEVICE"
}

health_check(){
  adb start-server >/dev/null 2>&1
  if ! adb -s "$DEVICE" get-state >/dev/null 2>&1; then
    log_warn "Device $DEVICE unreachable, restarting server"
    adb kill-server >/dev/null 2>&1 || true
    adb start-server >/dev/null 2>&1
    adb -s "$DEVICE" get-state >/dev/null 2>&1 || { log_error "Device $DEVICE unhealthy"; exit 1; }
  fi
  adb -s "$DEVICE" wait-for-device >/dev/null 2>&1
}

adb_s(){ adb -s "$DEVICE" "$@"; }

#####################
# RUN SETUP
#####################
init_run(){
  RUN_ID="$(date +%Y%m%d_%H%M%S)"
  RUN_DIR="$OUTDIR/$DEVICE/$RUN_ID"
  mkdir -p "$RUN_DIR/raw" "$RUN_DIR/apks" "$RUN_DIR/reports"
  ln -sfn "$RUN_DIR" "$OUTDIR/$DEVICE/latest"
  MASTER_CSV="$RUN_DIR/${DEVICE}.${RUN_ID}.apps.csv"
  SUMMARY_FILE="$RUN_DIR/${DEVICE}.${RUN_ID}.summary.txt"
  ROOT_FILE="$RUN_DIR/${DEVICE}.${RUN_ID}.root_status.txt"
  RAW_PM_LIST="$RUN_DIR/raw/raw_pm_list.txt"
  PARSER_VERSION="1.0"
  TOOL_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
  ADB_VERSION="$(adb version | head -n1 | awk '{print $3}')"
  CAPTURED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  SOURCE_CMD="adb -s $DEVICE shell pm list packages -f"
  HEADER="device_serial,run_id,package,apk_path,partition,is_user,is_social,social_method,version_name,version_code,permissions,sha256,hash_source,is_running,detection_notes,source_cmd,parser_version,tool_commit,adb_version,captured_at"
  write_csv_header "$MASTER_CSV" "$HEADER"
  log_info "Run ID: $RUN_ID"
  log_info "Run directory: $RUN_DIR"
}

#####################
# DISCOVERY
#####################
discover_packages(){
  log_info "Discovering packages"
  adb_s shell pm list packages -f | tr -d '\r' > "$RAW_PM_LIST"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    entry=${line#package:}
    apk_path=${entry%%=*}
    pkg=${entry##*=}
    partition=$(echo "$apk_path" | cut -d/ -f2)
    is_user=false; [[ "$partition" == "data" ]] && is_user=true
    append_csv_row "$MASTER_CSV" "$DEVICE,$RUN_ID,$pkg,$apk_path,$partition,$is_user,false,none,N/A,N/A,,,none,false,pm list,$SOURCE_CMD,$PARSER_VERSION,$TOOL_COMMIT,$ADB_VERSION,$CAPTURED_AT"
  done < "$RAW_PM_LIST"
  RAW_COUNT=$(wc -l < "$RAW_PM_LIST")
  CSV_COUNT=$(( $(wc -l < "$MASTER_CSV") -1 ))
  [[ $RAW_COUNT -eq $CSV_COUNT ]] || { log_error "Discovery count mismatch"; exit 1; }
  log_info "apps inventory updated: $CSV_COUNT rows"
}

#####################
# SOCIAL TRIAGE
#####################
social_triage(){
  log_info "Running social triage"
  local tmp="$MASTER_CSV.tmp"; echo "$HEADER" > "$tmp"
  tail -n +2 "$MASTER_CSV" | while IFS=',' read -r dev run pkg apk_path partition is_user is_social social_method version_name version_code permissions sha256 hash_source is_running detection_notes source_cmd parser_version tool_commit adb_version captured_at; do
    social=$is_social; method=$social_method; notes=$detection_notes
    for entry in "${SOCIAL_APPS[@]}"; do
      canonical=${entry%%:*}
      if [[ "$pkg" == "$canonical" ]]; then
        social=true; method=exact; notes="exact:$pkg"; break
      fi
    done
    if [[ "$social" == false ]]; then
      for kw in "${SOCIAL_KEYWORDS[@]}"; do
        if [[ "$pkg" == *"$kw"* ]]; then social=true; method=heuristic; notes="keyword:$kw"; break; fi
      done
    fi
    echo "$dev,$run,$pkg,$apk_path,$partition,$is_user,$social,$method,$version_name,$version_code,$permissions,$sha256,$hash_source,$is_running,$notes,$source_cmd,$parser_version,$tool_commit,$adb_version,$captured_at" >> "$tmp"
  done
  mv "$tmp" "$MASTER_CSV"
}

#####################
# METADATA
#####################
extract_metadata(){
  log_info "Extracting metadata"
  tail -n +2 "$MASTER_CSV" | cut -d, -f3,4 | while IFS=',' read -r pkg apk_path; do
    VERSION_NAME=$(adb_s shell dumpsys package "$pkg" | awk -F= '/versionName=/{print $2;exit}' | tr -d '\r')
    VERSION_CODE=$(adb_s shell dumpsys package "$pkg" | awk -F= '/versionCode=/{gsub(/ .*/,"",$2);print $2;exit}' | tr -d '\r')
    PERMS=$(adb_s shell dumpsys package "$pkg" | grep -E "permission " | awk '{print $1}' | paste -sd ';' -)
    update_field "$MASTER_CSV" "$pkg" 9 "${VERSION_NAME:-N/A}"
    update_field "$MASTER_CSV" "$pkg" 10 "${VERSION_CODE:-N/A}"
    update_field "$MASTER_CSV" "$pkg" 11 "${PERMS}"
  done
  MISSING=$(tail -n +2 "$MASTER_CSV" | awk -F, '$9==""' | wc -l)
  [[ $MISSING -eq 0 ]] || log_warn "$MISSING packages missing version info"
}

#####################
# HASHING
#####################
compute_hashes(){
  log_info "Hashing APKs"
  tail -n +2 "$MASTER_CSV" | cut -d, -f3,4 | while IFS=',' read -r pkg apk_path; do
    HASH=$(adb_s shell sha256sum "$apk_path" 2>/dev/null | awk '{print $1}')
    SRC="device"
    if [[ -z "$HASH" ]]; then
      if adb_s pull "$apk_path" "$RUN_DIR/apks/$pkg.apk" >/dev/null 2>&1; then
        HASH=$(sha256sum "$RUN_DIR/apks/$pkg.apk" | awk '{print $1}')
        SRC="host"
      else
        update_field "$MASTER_CSV" "$pkg" 15 "hash failed (no access)"
      fi
    fi
    [[ -n "$HASH" ]] && update_field "$MASTER_CSV" "$pkg" 12 "$HASH" && update_field "$MASTER_CSV" "$pkg" 13 "$SRC"
  done
  HASHED=$(tail -n +2 "$MASTER_CSV" | awk -F, '$12!=""' | wc -l)
  TOTAL=$(( $(wc -l < "$MASTER_CSV") -1 ))
  log_info "Hashes computed: $HASHED/$TOTAL"
}

#####################
# RUNNING PROCESSES
#####################
check_running(){
  log_info "Checking running processes"
  tail -n +2 "$MASTER_CSV" | cut -d, -f3 | while read -r pkg; do
    PID=$(adb_s shell pidof "$pkg" 2>/dev/null | tr -d '\r')
    [[ -n "$PID" ]] && update_field "$MASTER_CSV" "$pkg" 14 true
  done
}

#####################
# ROOT PROBE
#####################
root_probe(){
  log_info "Probing root capabilities"
  {
    echo "adb root:"; adb -s "$DEVICE" root 2>&1 || true
    echo "su -c id:"; adb -s "$DEVICE" shell su -c id 2>&1 || true
  } > "$ROOT_FILE"
}

#####################
# SUMMARY
#####################
write_summary(){
  local total social_exact social_heuristic running_social hash_ok hash_fail user_pkgs
  total=$(( $(wc -l < "$MASTER_CSV") -1 ))
  user_pkgs=$(tail -n +2 "$MASTER_CSV" | awk -F, '$6=="true"' | wc -l)
  social_exact=$(tail -n +2 "$MASTER_CSV" | awk -F, '$7=="true" && $8=="exact"' | wc -l)
  social_heuristic=$(tail -n +2 "$MASTER_CSV" | awk -F, '$7=="true" && $8=="heuristic"' | wc -l)
  running_social=$(tail -n +2 "$MASTER_CSV" | awk -F, '$7=="true" && $14=="true"' | wc -l)
  hash_ok=$(tail -n +2 "$MASTER_CSV" | awk -F, '$12!=""' | wc -l)
  hash_fail=$((total-hash_ok))
  {
    echo "Artifact naming: <serial>.<run-id>.<artifact>.<ext>"
    echo "Device: $DEVICE"
    echo "Run ID: $RUN_ID"
    echo "Total packages: $total"
    echo "User packages: $user_pkgs"
    echo "Social apps (exact): $social_exact"
    echo "Social apps (heuristic): $social_heuristic"
    echo "Running social apps: $running_social"
    echo "Hashes: $hash_ok success / $hash_fail failure"
    printf "\nSocial app summary:\n"
    tail -n +2 "$MASTER_CSV" | awk -F, '$7=="true"{printf "%-40s %-9s %s\n", $3, $8, ($12!=""?"hash" : "nohash");}'
    printf "\nArtifacts live under: %s\n" "$RUN_DIR"
    printf "\nNext actions:\n  # inspect a package\n  adb -s %s shell dumpsys package <package>\n" "$DEVICE"
  } > "$SUMMARY_FILE"
}

#####################
# DERIVED VIEWS (OPTIONAL)
#####################
generate_derived_views(){
  [ "$GENERATE_DERIVED" = true ] || return 0
  local social="$RUN_DIR/${DEVICE}.${RUN_ID}.social_apps_derived.csv"
  local running="$RUN_DIR/${DEVICE}.${RUN_ID}.running_apps_derived.csv"
  { echo "$HEADER"; tail -n +2 "$MASTER_CSV" | awk -F, '$7=="true"{print}' ; } > "$social"
  { echo "$HEADER"; tail -n +2 "$MASTER_CSV" | awk -F, '$14=="true"{print}' ; } > "$running"
}

#####################
# CSV FIELD UPDATER
#####################
update_field(){
  local file="$1" pkg="$2" col="$3" val="$4"
  awk -F, -v pkg="$pkg" -v col="$col" -v val="$val" 'BEGIN{OFS=","} NR==1{print;next} $3==pkg{$col=val} {print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}


#####################
# MAIN FLOW
#####################
check_adb
DEVICE=$(select_device)
log_info "Selected device: $DEVICE"
health_check
[[ $NON_INTERACTIVE -eq 1 ]] && log_info "Non-interactive mode"
init_run
discover_packages
social_triage
extract_metadata
compute_hashes
check_running
root_probe
write_summary
generate_derived_views

log_info "Run complete"
log_info "Master inventory → $MASTER_CSV"
log_info "Summary → $SUMMARY_FILE"
