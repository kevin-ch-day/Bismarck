#!/bin/bash
# colors.sh - Color variables with graceful fallback

[ -n "${UI_COLORS_SH_LOADED:-}" ] && return 0
UI_COLORS_SH_LOADED=1

# Default empty values
RESET=""
BOLD=""
CYAN=""
GREEN=""
YELLOW=""
RED=""
MAGENTA=""
WHITE=""
GRAY=""

if [ -z "${NO_COLOR:-}" ]; then
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        ncolors=$(tput colors 2>/dev/null || echo 0)
        if [ "$ncolors" -ge 8 ]; then
            RESET=$(tput sgr0)
            BOLD=$(tput bold)
            CYAN=$(tput setaf 6)
            GREEN=$(tput setaf 2)
            YELLOW=$(tput setaf 3)
            RED=$(tput setaf 1)
            MAGENTA=$(tput setaf 5)
            WHITE=$(tput setaf 7)
            GRAY=$(tput setaf 8 2>/dev/null || tput setaf 0)
        fi
    fi
fi

export RESET BOLD CYAN GREEN YELLOW RED MAGENTA WHITE GRAY
