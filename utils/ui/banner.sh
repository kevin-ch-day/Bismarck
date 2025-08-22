#!/bin/bash
# banner.sh - banner and section helpers

[ -n "${UI_BANNER_SH_LOADED:-}" ] && return 0
UI_BANNER_SH_LOADED=1

print_banner() {
    if command -v clear >/dev/null 2>&1; then
        clear
    fi
    printf '%s' "${CYAN}${BOLD}"
    box_title "Android Analysis Framework"
    printf '%s' "${RESET}"
}

print_section() {
    local text="$1"
    printf '%s%s%s\n' "${MAGENTA}${BOLD}" "$text" "${RESET}"
    hr "${#text}"
}

print_device_banner() {
    local serial="$1"
    local manufacturer="$2"
    local model="$3"
    local android="$4"
    local sdk="$5"

    local lines=(
        "Serial: $serial"
        "Manufacturer: $manufacturer"
        "Model: $model"
        "Android: $android"
        "SDK: $sdk"
    )

    local width=0
    local line
    for line in "${lines[@]}"; do
        if [ ${#line} -gt $width ]; then
            width=${#line}
        fi
    done
    local border=$(printf '%*s' "$width" '' | tr ' ' "$GL_H")

    printf '%s' "${CYAN}${BOLD}"
    echo "${GL_BOX_TL}${border}${GL_BOX_TR}"
    for line in "${lines[@]}"; do
        local pad=$(( width - ${#line} ))
        printf '%s%s%*s%s\n' "$GL_V" "$line" "$pad" '' "$GL_V"
    done
    echo "${GL_BOX_BL}${border}${GL_BOX_BR}"
    printf '%s' "${RESET}"
}

export -f print_banner print_section print_device_banner
