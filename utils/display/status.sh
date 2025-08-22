#!/bin/bash
# Library: display/status.sh
# Purpose: Status message helpers for terminal output

status_ok()    { echo -e "[${GREEN}✔${RESET}] ${WHITE}$*${RESET}"; }
status_warn()  { echo -e "[${YELLOW}⚠${RESET}] ${WHITE}$*${RESET}"; }
status_error() { echo -e "[${RED}✘${RESET}] ${WHITE}$*${RESET}"; }
status_info()  { echo -e "[${CYAN}ℹ${RESET}] ${WHITE}$*${RESET}"; }

print_detected() { echo -e "${GREEN}[+]${RESET} ${WHITE}Detected social app:${RESET} $*"; }
print_unknown()  { echo -e "${YELLOW}[-]${RESET} ${WHITE}Package found but not in SOCIAL_APPS list:${RESET} $*"; }
print_none()     { echo -e "${RED}[!]${RESET} ${WHITE}No matches found.${RESET}"; }
