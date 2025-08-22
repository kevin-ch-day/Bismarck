#!/bin/bash
# Script: make_executable.sh
# Purpose: Ensure all .sh scripts in the project are executable
# Author: Android_Tool Project
# Notes:
#   - Skips already-executable files
#   - Provides summary at the end
#   - Supports verbose/debug mode

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CHANGED=0
UNCHANGED=0
DEBUG_MODE="${DEBUG_MODE:-0}"

log() {
    local level="$1"
    local msg="$2"
    local ts
    ts="$(date '+%F %T')"
    echo "[$ts] [$level] $msg"
}

debug() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        log "DEBUG" "$1"
    fi
}

echo ""
log "INFO" "Scanning for .sh scripts under: $ROOT_DIR"
echo ""

# Find all .sh files and process them
while IFS= read -r script; do
    if [ ! -x "$script" ]; then
        chmod +x "$script"
        log "INFO" "Made executable: $script"
        ((CHANGED++))
    else
        debug "Already executable: $script"
        ((UNCHANGED++))
    fi
done < <(find "$ROOT_DIR" -type f -name "*.sh")

echo ""
log "INFO" "Scan complete."
log "INFO" "Files updated   : $CHANGED"
log "INFO" "Already correct : $UNCHANGED"
echo ""
