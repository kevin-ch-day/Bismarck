#!/bin/bash
# menu.sh - menu rendering

[ -n "${UI_MENU_SH_LOADED:-}" ] && return 0
UI_MENU_SH_LOADED=1

_menu_header() {
    printf '%s%s%s\n' "${CYAN}${BOLD}" "===== Android Tool Menu =====" "${RESET}"
}

_menu_option() {
    local num="$1"
    local label="$2"
    printf '%s%s%s) %s\n' "${YELLOW}${BOLD}" "$num" "${RESET}" "$label"
}

_menu_footer() {
    printf '%s%s%s\n' "${GRAY}" "0) Exit" "${RESET}"
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

export -f _menu_header _menu_option _menu_footer print_menu
