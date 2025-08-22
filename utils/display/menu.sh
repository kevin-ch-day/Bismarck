#!/bin/bash
# Library: display/menu.sh
# Purpose: Menu rendering helpers with back-compat aliases

# Back-compat aliases
show_menu_header() { _menu_header "$@"; }
show_menu_option() { _menu_option "$@"; }
show_menu_footer() { _menu_footer; }

_menu_header() {
  local device="$1"
  echo -e "${CYAN}${BOLD}┌──────────────── Android Tool Menu ────────────────┐${RESET}"
  if [[ -n "$device" ]]; then
    printf "${CYAN}${BOLD}│${RESET} Device: ${WHITE}%s${RESET}\n" "$device"
    echo -e "${CYAN}${BOLD}├───────────────────────────────────────────────────┤${RESET}"
  fi
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
  _menu_header "$1"
  _menu_option 1 "📦 List all APKs"
  _menu_option 2 "🌐 Scan social apps"
  _menu_option 3 "📱 List Motorola apps"
  _menu_option 4 "🔐 Compute SHA-256 hashes"
  _menu_option 5 "📝 Extract APK metadata"
  _menu_option 6 "🧠 Show running processes"
  _menu_option 7 "🎵 Pull TikTok APK"
  _menu_option 8 "📸 Capture screenshot"
  _menu_option 9 "🐚 Open device shell"
  _menu_option 10 "🚀 Run all"
  _menu_option 11 "🔁 Switch device"
  _menu_option 12 "📄 View social report"
  _menu_option 13 "📄 View Motorola report"
  _menu_footer
}
