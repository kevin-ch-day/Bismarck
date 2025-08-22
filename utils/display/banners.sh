#!/bin/bash
# Library: display/banners.sh
# Purpose: Banner and section printing helpers

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
