#!/bin/bash
# Library: display/menu.sh
# Purpose: Menu rendering helpers with back-compat aliases

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
