#!/usr/bin/env bash
# bootstrap_apk_workspace.sh
# Minimal setup for per-device, per-run APK workspace + convenience link.

set -euo pipefail

# ---- change here if you want a different package focus ----
PACKAGE="com.zhiliaoapp.musically"

# ---- derived defaults (no CLI flags) ----
ROOT="output"
RUN_TS="$(date +%Y%m%d_%H%M%S)"
DEVICE=""

log() { printf '%s\n' "$*"; }

# ---- pick a device or go offline ----
if command -v adb >/dev/null 2>&1; then
  mapfile -t DEVICES < <(adb devices -l | awk '/\tdevice$/{print $1}')
  if [[ ${#DEVICES[@]} -eq 1 ]]; then
    DEVICE="${DEVICES[0]}"
    log "[*] Device: ${DEVICE}"
  elif [[ ${#DEVICES[@]} -gt 1 ]]; then
    DEVICE="${DEVICES[0]}"
    log "[*] Multiple devices detected; using first: ${DEVICE}"
    printf '    Others: %s\n' "${DEVICES[@]:1}"
  else
    DEVICE="LOCAL_OFFLINE"
    log "[*] No devices; proceeding in offline mode (device=${DEVICE})"
  fi
else
  DEVICE="LOCAL_OFFLINE"
  log "[*] adb not found; proceeding in offline mode (device=${DEVICE})"
fi

# ---- build paths ----
DEVICE_DIR="${ROOT}/${DEVICE}"
RUN_DIR="${DEVICE_DIR}/${RUN_TS}"
APKS_DIR="${RUN_DIR}/apks"
RAW_DIR="${RUN_DIR}/raw"
REPORTS_DIR="${RUN_DIR}/reports"

# ---- create structure ----
mkdir -p "${APKS_DIR}" "${RAW_DIR}" "${REPORTS_DIR}"
ln -sfn "${RUN_DIR}" "${DEVICE_DIR}/latest"

# ---- convenience link at repo root: downloads -> <run>/apks ----
LINK_NAME="downloads"
if [[ -L "${LINK_NAME}" ]]; then
  ln -sfn "${APKS_DIR}" "${LINK_NAME}"
elif [[ -d "${LINK_NAME}" ]]; then
  # If empty directory, replace with symlink; else create downloads_latest
  if [[ -z "$(ls -A "${LINK_NAME}")" ]]; then
    rmdir "${LINK_NAME}"
    ln -sfn "${APKS_DIR}" "${LINK_NAME}"
  else
    ln -sfn "${APKS_DIR}" "${LINK_NAME}_latest"
    log "[*] '${LINK_NAME}' exists and is not empty; created '${LINK_NAME}_latest' -> ${APKS_DIR}"
  fi
else
  rm -f "${LINK_NAME}" 2>/dev/null || true
  ln -sfn "${APKS_DIR}" "${LINK_NAME}"
fi

# ---- move existing TikTok splits in repo root into apks/ ----
shopt -s nullglob
moved=0
for f in "${PACKAGE}-"*.apk; do
  mv -v -- "$f" "${APKS_DIR}/"
  ((moved++)) || true
done
if [[ $moved -gt 0 ]]; then
  log "[*] Moved ${moved} file(s) into ${APKS_DIR}"
else
  log "[*] No files matching '${PACKAGE}-*.apk' in $(pwd)"
fi

# ---- write SHA-256 manifest for whatever is in apks/ ----
if command -v sha256sum >/dev/null 2>&1; then
  shopt -s nullglob
  apk_list=( "${APKS_DIR}/"*.apk )
  if [[ ${#apk_list[@]} -gt 0 ]]; then
    MANIFEST="${REPORTS_DIR}/${PACKAGE}.sha256.txt"
    ( cd "${APKS_DIR}" && sha256sum *.apk ) > "${MANIFEST}"
    log "[*] Wrote hash manifest: ${MANIFEST}"
  else
    log "[*] No APKs in ${APKS_DIR}; skipping hash manifest."
  fi
else
  log "[!] sha256sum not found; skipping hash manifest."
fi

# ---- tiny README for humans ----
cat > "${RUN_DIR}/README.txt" <<TXT
Run: ${RUN_TS}
Device: ${DEVICE}
Package focus: ${PACKAGE}

Folders:
  apks/     <- place/pulled APK splits here
  raw/      <- raw command outputs (e.g., pm list)
  reports/  <- csv/manifests/hashes

Convenience:
  downloads -> ${APKS_DIR}
  latest    -> ${RUN_DIR}
TXT

# ---- summary ----
log "[+] Setup complete."
log "    Run folder : ${RUN_DIR}"
log "    APK drop   : ${APKS_DIR}"
log "    Shortcut   : ./downloads -> ${APKS_DIR}"
