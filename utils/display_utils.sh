#!/bin/bash
# display_utils.sh - thin loader for UI modules

[ -n "${DISPLAY_UTILS_SH_LOADED:-}" ] && return 0
DISPLAY_UTILS_SH_LOADED=1

set -u

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
UI_DIR="$SCRIPT_DIR/ui"

for mod in colors glyphs layout banner menu status spinner; do
    # shellcheck disable=SC1090
    [ -f "$UI_DIR/${mod}.sh" ] && . "$UI_DIR/${mod}.sh"
done

export -f \
    print_banner print_section print_device_banner \
    print_menu \
    status_ok status_warn status_error status_info \
    print_detected print_unknown print_none \
    start_spinner stop_spinner \
    hr box_title

show_banner() { print_banner "$@"; }
show_section() { print_section "$@"; }
show_menu_header() { _menu_header "$@"; }
show_menu_option() { _menu_option "$@"; }
show_menu_footer() { _menu_footer "$@"; }

export -f show_banner show_section show_menu_header show_menu_option show_menu_footer
