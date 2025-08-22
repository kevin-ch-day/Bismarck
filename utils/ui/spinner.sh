#!/bin/bash
# spinner.sh - simple ASCII spinner

[ -n "${UI_SPINNER_SH_LOADED:-}" ] && return 0
UI_SPINNER_SH_LOADED=1

_spinner_pid=""
_spinner_msg=""

start_spinner() {
    [ -n "$_spinner_pid" ] && return 0
    _spinner_msg="$1"
    if ! [ -t 1 ]; then
        echo "$_spinner_msg"
        _spinner_pid="print_only"
        return 0
    fi
    printf '%s ' "$_spinner_msg"
    if command -v tput >/dev/null 2>&1; then
        tput civis >/dev/null 2>&1
    fi
    (
        local i=0
        local frames=${#SPIN_FRAMES[@]}
        while true; do
            printf '%s' "${SPIN_FRAMES[i]}"
            sleep 0.1
            printf '\b'
            i=$(( (i + 1) % frames ))
        done
    ) &
    _spinner_pid=$!
}

stop_spinner() {
    case "$_spinner_pid" in
        "") return 0 ;;
        print_only)
            printf '%s%s%s\n' "${GREEN}${BOLD}" "$GL_TICK" "${RESET}"
            _spinner_pid=""
            _spinner_msg=""
            return 0
            ;;
    esac
    kill "$_spinner_pid" >/dev/null 2>&1
    wait "$_spinner_pid" 2>/dev/null
    printf '\b%s%s%s\n' "${GREEN}${BOLD}" "$GL_TICK" "${RESET}"
    if command -v tput >/dev/null 2>&1; then
        tput cnorm >/dev/null 2>&1
    fi
    _spinner_pid=""
    _spinner_msg=""
}

export -f start_spinner stop_spinner
