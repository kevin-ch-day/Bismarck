#!/bin/bash
# glyphs.sh - ASCII glyph definitions

[ -n "${UI_GLYPHS_SH_LOADED:-}" ] && return 0
UI_GLYPHS_SH_LOADED=1

GL_TICK="[OK]"
GL_WARN="[!!]"
GL_ERR="[XX]"
GL_INFO="[ i]"
GL_PLUS="+"
GL_MINUS="-"
GL_NONE="--"

GL_BOX_TL="+"
GL_BOX_TR="+"
GL_BOX_BL="+"
GL_BOX_BR="+"
GL_H="-"
GL_V="|"

GL_PROMPT=">"

SPIN_FRAMES=("|" "/" "-" "\\")

export GL_TICK GL_WARN GL_ERR GL_INFO GL_PLUS GL_MINUS GL_NONE \
       GL_BOX_TL GL_BOX_TR GL_BOX_BL GL_BOX_BR GL_H GL_V \
       GL_PROMPT SPIN_FRAMES
