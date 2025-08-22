#!/bin/bash
# Library: display_utils.sh
# Purpose: Enhanced terminal display utilities for Android analysis project
# Optimized for black-background terminals; graceful fallback if no color

########################################
# COLOR / STYLE SETUP (with fallback)
########################################
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && command -v tput >/dev/null 2>&1; then
  if [[ $(tput colors 2>/dev/null || echo 0) -ge 8 ]]; then
    RESET="\e[0m"; BOLD="\e[1m"
    CYAN="\e[96m"; GREEN="\e[92m"; YELLOW="\e[93m"; RED="\e[91m"
    MAGENTA="\e[95m"; WHITE="\e[97m"; GRAY="\e[90m"
  else
    RESET=""; BOLD=""
    CYAN=""; GREEN=""; YELLOW=""; RED=""
    MAGENTA=""; WHITE=""; GRAY=""
  fi
else
  RESET=""; BOLD=""
  CYAN=""; GREEN=""; YELLOW=""; RED=""
  MAGENTA=""; WHITE=""; GRAY=""
fi

# Utility: print a horizontal rule
hr() {
  local w="${1:-50}"
  printf '%*s\n' "$w" '' | tr ' ' '─'
}

########################################
# BANNERS / HEADERS
########################################

# Back-compat alias: show_banner -> print_banner
show_banner() { print_banner; }

print_banner() {
  clear 2>/dev/null
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║               Android Analysis Framework                 ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# Back-compat alias: show_section -> print_section
show_section() { print_section "$@"; }

print_section() {
  local title="${1:-Section}"
  echo -e "${MAGENTA}${BOLD}>>> ${title}${RESET}"
  echo -e "${GRAY}$(hr 60)${RESET}"
}

# Device info panel
print_device_banner() {
  local serial="${1:-unknown}"
  local mfg="${2:-unknown}"
  local model="${3:-unknown}"
  local android="${4:-unknown}"
  local sdk="${5:-unknown}"

  echo -e "${GREEN}${BOLD}Connected Device${RESET}"
  echo -e "${GRAY}$(hr 60)${RESET}"
  echo -e "${WHITE} Serial     :${RESET} ${CYAN}${serial}${RESET}"
  echo -e "${WHITE} Manufacturer:${RESET} ${CYAN}${mfg}${RESET}"
  echo -e "${WHITE} Model      :${RESET} ${CYAN}${model}${RESET}"
  echo -e "${WHITE} Android    :${RESET} ${CYAN}${android}${RESET}"
  echo -e "${WHITE} SDK        :${RESET} ${CYAN}${sdk}${RESET}"
  echo -e "${GRAY}$(hr 60)${RESET}"
}

########################################
# MENU (with back-compat aliases)
########################################

# Back-compat aliases
show_menu_header() { _menu_header; }
show_menu_option() { _menu_option "$@"; }
show_menu_footer() { _menu_footer; }

_menu_header() {
  echo -e "${CYAN}${BOLD}┌──────────────── Android Tool Menu ────────────────┐${RESET}"
}
_menu_option() {
  local num="$1"; shift
  local label="$*"
  echo -e " ${YELLOW}${BOLD}${num})${RESET} ${WHITE}${label}${RESET}"
}
_menu_footer() {
  echo -e " ${GRAY}0) Exit${RESET}"
  echo -e "${CYAN}${BOLD}└───────────────────────────────────────────────────┘${RESET}"
}

# Single-call printer used by run.sh
print_menu() {
  _menu_header
  _menu_option 1 "List all APKs"
  _menu_option 2 "Filter social apps"
  _menu_option 3 "Compute SHA-256 hashes"
  _menu_option 4 "Extract APK metadata"
  _menu_option 5 "Show running processes"
  _menu_option 6 "Run all"
  _menu_footer
}

########################################
# STATUS MESSAGES
########################################

status_ok()    { echo -e "[${GREEN}✔${RESET}] ${WHITE}$*${RESET}"; }
status_warn()  { echo -e "[${YELLOW}⚠${RESET}] ${WHITE}$*${RESET}"; }
status_error() { echo -e "[${RED}✘${RESET}] ${WHITE}$*${RESET}"; }
status_info()  { echo -e "[${CYAN}ℹ${RESET}] ${WHITE}$*${RESET}"; }

# Social app discovery helpers
print_detected() { echo -e "${GREEN}[+]${RESET} ${WHITE}Detected social app:${RESET} $*"; }
print_unknown()  { echo -e "${YELLOW}[-]${RESET} ${WHITE}Package found but not in SOCIAL_APPS list:${RESET} $*"; }
print_none()     { echo -e "${RED}[!]${RESET} ${WHITE}No matches found.${RESET}"; }

########################################
# SPINNER (for long tasks)
# Usage:
#   start_spinner "Doing things..."
#   <your long task>
#   stop_spinner
########################################
__spinner_pid=""

start_spinner() {
  local msg="$*"
  # Hide cursor if possible
  tput civis 2>/dev/null || true
  echo -ne "[${CYAN}…${RESET}] ${WHITE}${msg}${RESET} "
  (
    # Keep using stdout of parent tty
    while true; do
      for s in '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏'; do
        echo -ne "\b$s"
        sleep 0.1
      done
    done
  ) &
  __spinner_pid=$!
}

stop_spinner() {
  if [[ -n "$__spinner_pid" ]]; then
    kill "$__spinner_pid" >/dev/null 2>&1 || true
    wait "$__spinner_pid" 2>/dev/null || true
    __spinner_pid=""
    echo -ne "\b"
    echo -e " ${GREEN}done${RESET}"
    # Restore cursor
    tput cnorm 2>/dev/null || true
  fi
}

# Optional: export selected functions when sourced by other bash scripts
# (not strictly required, but can help in sub-shell contexts)
export -f print_banner print_section print_menu print_device_banner \
          status_ok status_warn status_error status_info \
          print_detected print_unknown print_none \
          start_spinner stop_spinner hr
