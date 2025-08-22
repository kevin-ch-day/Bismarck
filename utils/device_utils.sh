#!/bin/bash
# Library: device_utils.sh
# Provides helper functions for adb device readiness checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=utils/display/base.sh
source "$SCRIPT_DIR/display/base.sh"
# shellcheck source=utils/display/status.sh
source "$SCRIPT_DIR/display/status.sh"

# ensure_device_state SERIAL
# Verifies that the given device is in the 'device' state.
# Prints an error and returns non-zero if not.
ensure_device_state() {
    local dev="$1"
    local state
    state="$(adb -s "$dev" get-state 2>/dev/null || echo unknown)"
    if [[ "$state" != "device" ]]; then
        status_error "Device $dev not ready (state: $state)"
        return 1
    fi
}
