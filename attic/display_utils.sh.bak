#!/bin/bash
# Library: display_utils.sh
# Purpose: Aggregate terminal display utilities for Android analysis project

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source modular components
# shellcheck source=./display/base.sh
source "$SCRIPT_DIR/display/base.sh"
# shellcheck source=./display/banners.sh
source "$SCRIPT_DIR/display/banners.sh"
# shellcheck source=./display/menu.sh
source "$SCRIPT_DIR/display/menu.sh"
# shellcheck source=./display/status.sh
source "$SCRIPT_DIR/display/status.sh"
# shellcheck source=./display/spinner.sh
source "$SCRIPT_DIR/display/spinner.sh"

# Export selected functions for use in subshells
export -f print_banner print_section print_menu print_device_banner \
          status_ok status_warn status_error status_info \
          print_detected print_unknown print_none \
          start_spinner stop_spinner hr
