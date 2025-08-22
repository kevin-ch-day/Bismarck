#!/bin/bash
# status.sh - status and helper messages

[ -n "${UI_STATUS_SH_LOADED:-}" ] && return 0
UI_STATUS_SH_LOADED=1

status_ok() {
    local msg="$1"
    printf '%s%s%s %s\n' "${GREEN}${BOLD}" "$GL_TICK" "${RESET}" "$msg"
}

status_warn() {
    local msg="$1"
    printf '%s%s%s %s\n' "${YELLOW}${BOLD}" "$GL_WARN" "${RESET}" "$msg"
}

status_error() {
    local msg="$1"
    printf '%s%s%s %s\n' "${RED}${BOLD}" "$GL_ERR" "${RESET}" "$msg"
}

status_info() {
    local msg="$1"
    printf '%s%s%s %s\n' "${CYAN}${BOLD}" "$GL_INFO" "${RESET}" "$msg"
}

print_detected() {
    local pkg="$1"
    printf '%s%s%s Detected social app: %s\n' "${GREEN}${BOLD}" "$GL_PLUS" "${RESET}" "$pkg"
}

print_unknown() {
    local pkg="$1"
    printf '%s%s%s Package not in SOCIAL_APPS: %s\n' "${YELLOW}${BOLD}" "$GL_MINUS" "${RESET}" "$pkg"
}

print_none() {
    printf '! No matches found.\n'
}

export -f status_ok status_warn status_error status_info \
          print_detected print_unknown print_none
