#!/bin/bash
# Library: display/spinner.sh
# Purpose: Simple spinner to indicate progress for long-running tasks

__spinner_pid=""

start_spinner() {
  local msg="$*"
  tput civis 2>/dev/null || true
  echo -ne "[${CYAN}…${RESET}] ${WHITE}${msg}${RESET} "
  (
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
    tput cnorm 2>/dev/null || true
  fi
}
