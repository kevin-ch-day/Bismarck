#!/bin/bash
# shellcheck disable=SC2034
# Library: display/base.sh
# Purpose: Color variables and formatting helpers shared across display utilities

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
