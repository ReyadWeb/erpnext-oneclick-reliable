#!/usr/bin/env bash
# Common helpers with reliability hardening
set -Eeuo pipefail

LOG_DIR="/var/log/erpnext-oneclick"
STATE_DIR="/var/lib/erpnext-oneclick/state"
mkdir -p "$LOG_DIR" "$STATE_DIR"
LOG_FILE="${LOG_DIR}/install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

trap 'on_err $LINENO $? "$BASH_COMMAND"' ERR
on_err(){ local line="$1" code="$2" cmd="$3"
  printf "\n\033[1;31m✖ Error\033[0m at line %s (exit %s): %s\nSee log: %s\n" "$line" "$code" "$cmd" "$LOG_FILE" >&2
}

color(){ local c="$1"; shift; printf "\033[%sm%s\033[0m\n" "$c" "$*"; }
info(){  color "1;34" "ℹ $*"; }
ok(){    color "1;32" "✔ $*"; }
warn(){  color "1;33" "⚠ $*"; }
err(){   color "1;31" "✖ $*"; }

require_root(){
  if [[ "$(id -u)" -ne 0 ]]; then err "Run as root (sudo)."; exit 1; fi
}
require_sudo(){
  if [[ -z "${SUDO_USER:-}" && "$(id -u)" -ne 0 ]]; then err "sudo privileges are required."; exit 1; fi
}

# Resume/Idempotency: mark steps
step_run(){
  local name="$1"; shift
  local marker="${STATE_DIR}/${name}.done"
  if [[ -f "$marker" ]]; then
    ok "Step '${name}' already done. Skipping."
    return 0
  fi
  info ">> ${name}"
  "$@"
  touch "$marker"
  ok "Step '${name}' completed."
}

# Retry wrapper with dpkg/apt lock wait
with_retries(){
  local tries="${1:-5}"; shift
  local delay=4
  for ((i=1;i<=tries;i++)); do
    if "$@"; then return 0; fi
    warn "Attempt $i failed. Retrying in ${delay}s..."
    sleep "$delay"; delay=$((delay*2)); [[ $delay -gt 60 ]] && delay=60
  done
  err "Command failed after ${tries} attempts: $*"; return 1
}

wait_for_dpkg_lock(){
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    warn "Waiting for dpkg/apt lock..."; sleep 3
  done
}

apt_install(){
  wait_for_dpkg_lock
  DEBIAN_FRONTEND=noninteractive \
  with_retries 5 bash -lc "apt-get update -y && apt-get install -y $*"
}

apt_upgrade(){
  wait_for_dpkg_lock
  DEBIAN_FRONTEND=noninteractive \
  with_retries 5 bash -lc "apt-get update -y && apt-get upgrade -y"
}

# Networking checks
require_cmd(){ command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }
check_host(){
  local host="$1"
  if ! getent ahostsv4 "$host" >/dev/null; then warn "Cannot resolve $host"; return 1; fi
  return 0
}
check_http(){
  local url="$1"
  if ! curl -fsI --max-time 15 "$url" >/dev/null; then warn "Cannot reach $url"; return 1; fi
  return 0
}

# System sanity
detect_ubuntu(){
  . /etc/os-release
  if [[ "${VERSION_CODENAME}" != "noble" ]]; then
    warn "Detected ${PRETTY_NAME}. This targets Ubuntu 24.04 (noble). Proceeding anyway."
  else
    ok "Ubuntu 24.04 detected."
  fi
}

mem_mb(){ awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo; }
disk_gb(){ df -Pm / | awk 'NR==2{printf "%d", $4/1024}' ; } # free space

ensure_swap(){
  local need_mb="${1:-4096}"
  local have_swap; have_swap="$(awk '/SwapTotal/ {print $2}' /proc/meminfo)"
  if [[ "${have_swap:-0}" -lt 1024 ]]; then
    warn "No/low swap detected. Creating ${need_mb}MB swapfile to avoid OOM during build."
    fallocate -l "${need_mb}M" /swapfile || dd if=/dev/zero of=/swapfile bs=1M count="${need_mb}"
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    ok "Swap configured."
  else
    ok "Swap present."
  fi
}

# Validation helpers
is_valid_domain(){ [[ "$1" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; }

resolve_a_record(){ getent ahostsv4 "$1" | awk '{print $1}' | head -n1; }

preflight_checks(){
  info "Running preflight checks..."
  detect_ubuntu
  require_cmd curl; require_cmd git; require_cmd python3
  local mem="$(mem_mb)"; local disk="$(disk_gb)"
  info "Free RAM: ${mem}MB | Free disk: ${disk}GB"
  if [[ "$mem" -lt 3500 ]]; then warn "RAM < 3.5GB; swap will be added."; ensure_swap 4096; fi
  if [[ "$disk" -lt 25 ]]; then warn "Free disk < 25GB; consider expanding disk."; fi
  check_host "raw.githubusercontent.com" || true
  check_http "https://pypi.org/simple" || true
  ok "Preflight checks finished."
}

# Safe su -c for login shell (needed for nvm)
run_as_user(){
  local user="$1"; shift
  su - "$user" -c "bash -lc \"$*\""
}

# Append a line once to a file
append_once(){ local file="$1"; shift; local line="$*"; grep -qxF "$line" "$file" 2>/dev/null || echo "$line" >> "$file"; }

ensure_user(){
  local user="$1"
  if id "$user" &>/dev/null; then ok "User '$user' exists."
  else
    info "Creating user '$user'..."
    adduser --disabled-password --gecos "" "$user"
    usermod -aG sudo "$user"
    ok "User '$user' created and added to sudo."
  fi
}
