#!/usr/bin/env bash
# Lightweight TUI using whiptail if available, with safe fallbacks.
set -euo pipefail

_has_whiptail(){ command -v whiptail >/dev/null 2>&1; }

prompt(){
  local title="$1" text="$2" default="${3:-}"
  if _has_whiptail; then
    whiptail --title "$title" --inputbox "$text" 10 70 "$default" 3>&1 1>&2 2>&3
  else
    local ans
    read -rp "$(printf '%s\n%s [%s]: ' "$title" "$text" "$default")" ans
    echo "${ans:-$default}"
  fi
}

secret(){
  local title="$1" text="$2"
  if _has_whiptail; then
    whiptail --title "$title" --passwordbox "$text" 10 70 3>&1 1>&2 2>&3
  else
    local ans
    read -rsp "$(printf '%s\n%s: ' "$title" "$text")" ans; echo
    echo "$ans"
  fi
}

confirm(){
  local title="$1" text="$2"
  if _has_whiptail; then
    if whiptail --title "$title" --yesno "$text" 10 70; then
      echo "yes"; return 0
    else
      echo "no"; return 1
    fi
  else
    local ans
    read -rp "$(printf '%s\n%s [Y/n]: ' "$title" "$text")" ans
    case "${ans:-y}" in y|Y) echo "yes";; *) echo "no"; return 1;; esac
  fi
}

progress(){
  local msg="${1:-Working...}"
  if _has_whiptail; then
    whiptail --title "Working" --infobox "$msg" 8 70
  else
    echo ">> $msg"
  fi
}
