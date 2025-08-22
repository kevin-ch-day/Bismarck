#!/bin/bash
# Library: display_utils.sh
# Purpose: Enhanced terminal display utilities for Android analysis project
# Optimized for black background terminals

#####################
# COLORS & STYLES
#####################
RESET="\e[0m"
BOLD="\e[1m"

# Bright colors (high contrast on black background)
CYAN="\e[96m"
GREEN="\e[92m"
YELLOW="\e[93m"
RED="\e[91m"
MAGENTA="\e[95m"
WHITE="\e[97m"
GRAY="\e[90m"

#####################
# BANNER / HEADER
#####################

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════╗"
    echo "║       Android Analysis Framework      ║"
    echo "╚═══════════════════════════════════════╝"
    echo -e "${RESET}"
}

show_section() {
    local title="$1"
    echo -e "\n${MAGENTA}${BOLD}>>> $title${RESET}"
}

#####################
# MENU SYSTEM
#####################

show_menu_header() {
    echo -e "\n${CYAN}${BOLD}┌───── Android Tool Menu ─────┐${RESET}"
}

show_menu_option() {
    local num="$1"
    local label="$2"
    echo -e "${YELLOW}${BOLD}${num})${RESET} ${WHITE}$label${RESET}"
}

show_menu_footer() {
    echo -e "${CYAN}${BOLD}└─────────────────────────────┘${RESET}"
    echo -e "${GRAY}0) Exit${RESET}"
}

#####################
# STATUS MESSAGES
#####################

status_ok() {
    echo -e "[${GREEN}✔${RESET}] ${WHITE}$1${RESET}"
}

status_warn() {
    echo -e "[${YELLOW}⚠${RESET}] ${WHITE}$1${RESET}"
}

status_error() {
    echo -e "[${RED}✘${RESET}] ${WHITE}$1${RESET}"
}

status_info() {
    echo -e "[${CYAN}ℹ${RESET}] ${WHITE}$1${RESET}"
}

#####################
# SPINNER (for long tasks)
#####################
# Usage: start_spinner "Message..."; ... task ... ; stop_spinner

_spinner_pid=""

start_spinner() {
    local msg="$1"
    echo -ne "[${CYAN}…${RESET}] ${WHITE}$msg ${RESET}"
    (
        while true; do
            for s in "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"; do
                echo -ne "\b$s"
                sleep 0.1
            done
        done
    ) &
    _spinner_pid=$!
}

stop_spinner() {
    if [ -n "$_spinner_pid" ]; then
        kill "$_spinner_pid" >/dev/null 2>&1
        wait "$_spinner_pid" 2>/dev/null
        _spinner_pid=""
        echo -ne "\b"
        echo -e " ${GREEN}done${RESET}"
    fi
}
