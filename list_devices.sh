#!/bin/bash
# Library: list_devices.sh
# Provides: list_devices()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/display/base.sh"
source "$SCRIPT_DIR/utils/display/status.sh"

list_devices() {
    local preselect="$1"
    local devices
    local attempts=0

    # If a serial was provided or already set, just return it
    if [ -n "$preselect" ]; then
        DEVICE="$preselect"
        echo "$DEVICE"
        return 0
    fi

    if [ -n "${DEVICE:-}" ]; then
        echo "$DEVICE"
        return 0
    fi

    # Retry a few times in case the ADB server is still warming up
    while [ $attempts -lt 5 ]; do
        devices=$(adb devices -l 2>/dev/null | awk 'NR>1 && $2=="device" {print $0}')
        [ -n "$devices" ] && break
        ((attempts++))
        sleep 1
    done

    if [ -z "$devices" ]; then
        status_error "No connected devices found" >&2
        echo ""  # return empty string
        return 1
    fi

    status_info "Connected devices:" >&2
    local i=1
    local dev_arr=()
    while IFS= read -r d; do
        serial=$(echo "$d" | awk '{print $1}')
        model=$(echo "$d" | grep -o 'model:[^ ]*' | cut -d: -f2)
        product=$(echo "$d" | grep -o 'product:[^ ]*' | cut -d: -f2)
        transport=$(echo "$d" | grep -o 'transport_id:[^ ]*' | cut -d: -f2)
        printf "  ${YELLOW}${BOLD}[%d]${RESET} Serial: ${WHITE}%s${RESET}\n" "$i" "$serial" >&2
        printf "      Model: ${WHITE}%s${RESET} | Product: ${WHITE}%s${RESET} | Transport: ${WHITE}%s${RESET}\n" \
            "$model" \
            "$product" \
            "$transport" >&2
        dev_arr+=("$serial")
        ((i++))
    done <<< "$devices"

    if [ ${#dev_arr[@]} -eq 1 ]; then
        DEVICE="${dev_arr[0]}"
    else
        printf "${CYAN}[?]${RESET} ${BOLD}Select a device number:${RESET} " >&2
        read -r choice
        idx=$((choice-1))
        if [ -z "${dev_arr[$idx]}" ]; then
            echo ""
            return 1
        fi
        DEVICE="${dev_arr[$idx]}"
    fi

    export DEVICE
    echo "$DEVICE"
}
