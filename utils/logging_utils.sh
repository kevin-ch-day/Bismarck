#!/bin/bash
# Library: logging_utils.sh
# Purpose: Flexible logging utility with levels, colors, and timestamps
# Usage: source this file in run.sh or other project scripts

#####################
# CONFIG
#####################

# Default log file (overridden by run.sh via export LOGFILE)
LOGFILE="${LOGFILE:-./logs/default.log}"

# Debug flag (0 = off, 1 = on)
DEBUG_MODE="${DEBUG_MODE:-0}"

# Color support (disable if piping or redirected)
USE_COLORS="${USE_COLORS:-1}"
if [ ! -t 1 ]; then
    USE_COLORS=0
fi

#####################
# COLORS
#####################
if [ "$USE_COLORS" -eq 1 ]; then
    COLOR_RESET="\e[0m"
    COLOR_INFO="\e[32m"     # green
    COLOR_WARN="\e[33m"     # yellow
    COLOR_ERROR="\e[31m"    # red
    COLOR_DEBUG="\e[90m"    # gray
else
    COLOR_RESET=""
    COLOR_INFO=""
    COLOR_WARN=""
    COLOR_ERROR=""
    COLOR_DEBUG=""
fi

#####################
# INTERNAL FUNCTIONS
#####################

_log() {
    local level="$1"
    local msg="$2"
    local color="$3"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # terminal output (with color)
    echo -e "[$timestamp] [${color}${level}${COLOR_RESET}] $msg"

    # plain text into logfile
    echo "[$timestamp] [$level] $msg" >> "$LOGFILE"
}

#####################
# PUBLIC FUNCTIONS
#####################

log_info() {
    _log "INFO" "$1" "$COLOR_INFO"
}

log_warn() {
    _log "WARN" "$1" "$COLOR_WARN"
}

log_error() {
    _log "ERROR" "$1" "$COLOR_ERROR" >&2
}

log_debug() {
    if [ "$DEBUG_MODE" -eq 1 ]; then
        _log "DEBUG" "$1" "$COLOR_DEBUG"
    fi
}

#####################
# EXTRAS
#####################

# quick check for log rotation (if file > 5MB, rotate)
log_rotate() {
    if [ -f "$LOGFILE" ]; then
        local size
        size=$(stat -c%s "$LOGFILE" 2>/dev/null || echo 0)
        if [ "$size" -gt 5242880 ]; then   # 5 MB
            mv "$LOGFILE" "${LOGFILE%.log}_$(date '+%Y%m%d_%H%M%S').log"
            log_info "Rotated log file. New log at $LOGFILE"
        fi
    fi
}

# inline timer helpers (good for profiling)
log_start_timer() {
    TIMER_START=$(date +%s)
}

log_end_timer() {
    local end
    end=$(date +%s)
    local elapsed=$((end - TIMER_START))
    log_info "Elapsed time: ${elapsed}s"
}
