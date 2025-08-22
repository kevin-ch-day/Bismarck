#!/bin/bash
# layout.sh - layout helpers

[ -n "${UI_LAYOUT_SH_LOADED:-}" ] && return 0
UI_LAYOUT_SH_LOADED=1

hr() {
    local width="${1:-40}"
    local line
    printf -v line '%*s' "$width" ''
    line=${line// /$GL_H}
    printf '%s\n' "$line"
}

box_title() {
    local title="$1"
    local inner_width=$(( ${#title} + 2 ))
    local border
    printf -v border '%*s' "$inner_width" ''
    border=${border// /$GL_H}
    echo "${GL_BOX_TL}${border}${GL_BOX_TR}"
    echo "${GL_V} ${title} ${GL_V}"
    echo "${GL_BOX_BL}${border}${GL_BOX_BR}"
}

export -f hr box_title
