#!/bin/bash
# Library: list_devices.sh
# Provides: list_devices()

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

    if [ -n "$DEVICE" ]; then
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
        echo ""  # return empty string
        return 1
    fi

    echo "[*] Connected devices:" >&2
    local i=1
    local dev_arr=()
    while IFS= read -r d; do
        serial=$(echo "$d" | awk '{print $1}')
        model=$(echo "$d" | grep -o 'model:[^ ]*' | cut -d: -f2)
        product=$(echo "$d" | grep -o 'product:[^ ]*' | cut -d: -f2)
        transport=$(echo "$d" | grep -o 'transport_id:[^ ]*' | cut -d: -f2)
        echo "  [$i] Serial: $serial | Model: $model | Product: $product | Transport: $transport" >&2
        dev_arr+=("$serial")
        ((i++))
    done <<< "$devices"

    if [ ${#dev_arr[@]} -eq 1 ]; then
        DEVICE="${dev_arr[0]}"
    else
        printf "[?] Select a device number: " >&2
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
