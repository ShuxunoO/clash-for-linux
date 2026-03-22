#!/usr/bin/env bash

# ============================================
# clashctl UI library (scripts/ui.sh)
# 用户优先版：清晰、稳健、兼容、可读
# ============================================

# ---------- env ----------
: "${CLASHCTL_ASCII:=0}"
: "${UI_WIDTH:=0}"
: "${UI_SUMMARY_KEY_WIDTH:=12}"

# ---------- color ----------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'
  C_CYAN=$'\033[36m'
else
  C_RESET=''
  C_BOLD=''
  C_DIM=''
  C_RED=''
  C_GREEN=''
  C_YELLOW=''
  C_BLUE=''
  C_CYAN=''
fi

# ---------- unicode / ascii fallback ----------
_ui_is_utf8() {
  case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
    *UTF-8*|*utf8*) return 0 ;;
    *) return 1 ;;
  esac
}

if [ "$CLASHCTL_ASCII" = "1" ] || ! _ui_is_utf8; then
  UI_ASCII=1

  ICON_INFO="i"
  ICON_OK="OK"
  ICON_WARN="!!"
  ICON_ERR="XX"
  ICON_ARROW=">"
  ICON_DOT="-"

  BOX_TL="+"
  BOX_TR="+"
  BOX_BL="+"
  BOX_BR="+"
  BOX_H="-"
  BOX_V="|"
  BOX_JL="+"
  BOX_JR="+"
else
  UI_ASCII=0

  ICON_INFO="ℹ"
  ICON_OK="✔"
  ICON_WARN="⚠"
  ICON_ERR="✖"
  ICON_ARROW="→"
  ICON_DOT="•"

  BOX_TL="╔"
  BOX_TR="╗"
  BOX_BL="╚"
  BOX_BR="╝"
  BOX_H="═"
  BOX_V="║"
  BOX_JL="╠"
  BOX_JR="╣"
fi

TAG_INFO="${C_BLUE}${ICON_INFO}${C_RESET}"
TAG_OK="${C_GREEN}${ICON_OK}${C_RESET}"
TAG_WARN="${C_YELLOW}${ICON_WARN}${C_RESET}"
TAG_ERR="${C_RED}${ICON_ERR}${C_RESET}"

# ---------- width ----------
_ui_term_width() {
  local cols=""
  if command -v tput >/dev/null 2>&1; then
    cols="$(tput cols 2>/dev/null || true)"
  fi

  if [ -z "${cols:-}" ] && [ -n "${COLUMNS:-}" ]; then
    cols="$COLUMNS"
  fi

  if [ -z "${cols:-}" ] || ! [ "$cols" -gt 0 ] 2>/dev/null; then
    cols=80
  fi

  printf '%s\n' "$cols"
}

_ui_resolve_width() {
  local cols width
  cols="$(_ui_term_width)"

  if [ "${UI_WIDTH:-0}" -gt 0 ] 2>/dev/null; then
    width="$UI_WIDTH"
  else
    width=$((cols - 2))
  fi

  # 最小 56，最大 88，避免过窄/过宽
  [ "$width" -lt 56 ] && width=56
  [ "$width" -gt 88 ] && width=88

  printf '%s\n' "$width"
}

_ui_get_width() {
  printf '%s\n' "$(_ui_resolve_width)"
}

_ui_summary_inner_width() {
  echo $(( $(_ui_get_width) - 2 ))
}

# ---------- helpers ----------
ui_repeat() {
  local ch="$1"
  local n="$2"

  [ "$n" -le 0 ] && return 0
  printf '%*s' "$n" '' | tr ' ' "$ch"
}

ui_blank() {
  printf '\n'
}

ui_line() {
  local width
  width="$(_ui_get_width)"
  ui_repeat "-" "$width"
  printf '\n'
}

_ui_section_title() {
  local text="$1"
  printf '%b%s%b\n' "$C_BOLD" "$text" "$C_RESET"
}

ui_header() {
  local title="$1"
  local width
  width="$(_ui_get_width)"

  ui_repeat "=" "$width"
  printf '\n'
  printf ' %b%s%b\n' "$C_BOLD" "$title" "$C_RESET"
  ui_repeat "=" "$width"
  printf '\n'
}

ui_subheader() {
  local text="$1"
  _ui_section_title "$text"
}

ui_step() {
  local text="$1"
  printf '%b%s%b\n' "$C_BOLD" "$text" "$C_RESET"
}

ui_info() {
  printf '%b %s\n' "$TAG_INFO" "$*"
}

ui_ok() {
  printf '%b %s\n' "$TAG_OK" "$*"
}

ui_warn() {
  printf '%b %s\n' "$TAG_WARN" "$*"
}

ui_error() {
  printf '%b %s\n' "$TAG_ERR" "$*"
}

ui_kv() {
  local key="$1"
  local value="$2"
  printf '  %-14s : %s\n' "$key" "$value"
}

# ---------- text wrap ----------
_ui_wrap_print() {
  local indent="$1"
  local width="$2"
  local text="$3"
  local avail rest chunk

  [ -z "$text" ] && {
    printf '%s\n' "$indent"
    return 0
  }

  avail=$((width - ${#indent}))
  [ "$avail" -le 8 ] && avail=8

  rest="$text"
  while [ -n "$rest" ]; do
    if [ "${#rest}" -le "$avail" ]; then
      printf '%s%s\n' "$indent" "$rest"
      break
    fi

    chunk="${rest:0:$avail}"
    printf '%s%s\n' "$indent" "$chunk"
    rest="${rest:$avail}"
  done
}

# ---------- summary box ----------
ui_summary_begin() {
  local title="${1:-摘要}"
  local inner box_width

  inner="$(_ui_summary_inner_width)"
  box_width=$((inner - 2))

  printf '%s' "$BOX_TL"
  ui_repeat "$BOX_H" "$inner"
  printf '%s\n' "$BOX_TR"

  printf '%s %-*s %s\n' "$BOX_V" "$box_width" "$title" "$BOX_V"

  printf '%s' "$BOX_JL"
  ui_repeat "$BOX_H" "$inner"
  printf '%s\n' "$BOX_JR"
}

ui_summary_row() {
  local key="$1"
  local value="$2"
  local inner content_width prefix prefix_len rest chunk avail

  inner="$(_ui_summary_inner_width)"
  content_width=$((inner - 2))

  prefix=$(printf ' %-*s : ' "$UI_SUMMARY_KEY_WIDTH" "$key")
  prefix_len=${#prefix}

  if [ "$prefix_len" -ge "$content_width" ]; then
    prefix=" "
    prefix_len=1
  fi

  rest="${value:-}"
  avail=$((content_width - prefix_len))
  [ "$avail" -le 8 ] && avail=8

  if [ "${#rest}" -le "$avail" ]; then
    printf '%s %-*s %s\n' "$BOX_V" "$content_width" "${prefix}${rest}" "$BOX_V"
    return 0
  fi

  chunk="${rest:0:$avail}"
  printf '%s %-*s %s\n' "$BOX_V" "$content_width" "${prefix}${chunk}" "$BOX_V"
  rest="${rest:$avail}"

  while [ -n "$rest" ]; do
    if [ "${#rest}" -le "$avail" ]; then
      printf '%s %-*s %s\n' "$BOX_V" "$content_width" "$(printf '%*s%s' "$prefix_len" '' "$rest")" "$BOX_V"
      break
    fi

    chunk="${rest:0:$avail}"
    printf '%s %-*s %s\n' "$BOX_V" "$content_width" "$(printf '%*s%s' "$prefix_len" '' "$chunk")" "$BOX_V"
    rest="${rest:$avail}"
  done
}

ui_summary_end() {
  local inner
  inner="$(_ui_summary_inner_width)"

  printf '%s' "$BOX_BL"
  ui_repeat "$BOX_H" "$inner"
  printf '%s\n' "$BOX_BR"
}

# ---------- section blocks ----------
ui_next() {
  local item
  ui_blank
  ui_subheader "下一步"

  for item in "$@"; do
    [ -z "$item" ] && continue
    printf '  %s %s\n' "$ICON_ARROW" "$item"
  done
}

ui_fix_block() {
  local reason="$1"
  shift || true

  ui_blank
  ui_subheader "原因"
  printf '  %s\n' "$reason"

  if [ "$#" -gt 0 ]; then
    ui_blank
    ui_subheader "修复建议"
    local item
    for item in "$@"; do
      [ -z "$item" ] && continue
      printf '  %s %s\n' "$ICON_DOT" "$item"
    done
  fi
}

ui_debug_block() {
  [ "$#" -eq 0 ] && return 0

  ui_blank
  ui_subheader "调试信息"
  local item
  for item in "$@"; do
    [ -z "$item" ] && continue
    printf '  %s\n' "$item"
  done
}

ui_security_block() {
  [ "$#" -eq 0 ] && return 0

  ui_blank
  ui_subheader "安全提示"
  local item
  for item in "$@"; do
    [ -z "$item" ] && continue
    printf '  %s %s\n' "$ICON_DOT" "$item"
  done
}

# ---------- optional helpers ----------
ui_tip() {
  local text="$1"
  ui_info "$text"
}

ui_success_block() {
  local title="${1:-操作成功}"
  shift || true

  ui_blank
  ui_subheader "$title"
  local item
  for item in "$@"; do
    [ -z "$item" ] && continue
    printf '  %s %s\n' "$ICON_DOT" "$item"
  done
}

ui_warn_block() {
  local title="${1:-注意事项}"
  shift || true

  ui_blank
  ui_subheader "$title"
  local item
  for item in "$@"; do
    [ -z "$item" ] && continue
    printf '  %s %s\n' "$ICON_DOT" "$item"
  done
}

# ---------- exit helpers ----------
die() {
  local msg="$1"
  shift || true
  ui_error "$msg"
  exit 1
}

die_with_reason() {
  local msg="$1"
  local reason="$2"
  shift 2 || true
  ui_error "$msg"
  ui_fix_block "$reason" "$@"
  exit 1
}