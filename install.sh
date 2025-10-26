#!/usr/bin/env bash
# ERPNext One‑Click Installer (reliable edition)
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${REPO_DIR}/scripts/helpers.sh"

require_root
preflight_checks
apt_upgrade

# Flags
ENV_FILE=""
FRAPPE_USER="frappe"
SITE_NAME="erp.local"
ADMIN_PASSWORD="admin"
APPS="erpnext hrms payments"
FRAPPE_BRANCH="version-15"
PRODUCTION="no"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2;;
    --frappe-user) FRAPPE_USER="$2"; shift 2;;
    --site-name) SITE_NAME="$2"; shift 2;;
    --admin-password) ADMIN_PASSWORD="$2"; shift 2;;
    --apps) APPS="$2"; shift 2;;
    --frappe-branch) FRAPPE_BRANCH="$2"; shift 2;;
    --production) PRODUCTION="$2"; shift 2;;
    --mariadb-root) MYSQL_ROOT_PASSWORD="$2"; shift 2;;
    *) err "Unknown flag: $1"; exit 1;;
  esac
done

[[ -n "$ENV_FILE" && -f "$ENV_FILE" ]] && { info "Loading env from $ENV_FILE"; set -a; source "$ENV_FILE"; set +a; }

FRAPPE_HOME="${FRAPPE_HOME:-/home/${FRAPPE_USER}}"
info "Settings:
  FRAPPE_USER=${FRAPPE_USER}
  SITE_NAME=${SITE_NAME}
  APPS=${APPS}
  FRAPPE_BRANCH=${FRAPPE_BRANCH}
  PRODUCTION=${PRODUCTION}
  FRAPPE_HOME=${FRAPPE_HOME}
  Log file: $(readlink -f /var/log/erpnext-oneclick/install.log)
"

# Base packages
step_run sys.base apt_install git python3-dev python3-venv python3-pip python3-pip-whl \
  redis-server curl xvfb libfontconfig wkhtmltopdf software-properties-common \
  supervisor nginx ca-certificates lsb-release

# Hardening + whiptail
step_run sys.harden "${REPO_DIR}/scripts/harden.sh"

# User
step_run user.ensure ensure_user "$FRAPPE_USER"
step_run user.perms chmod -R o+rx "/home/${FRAPPE_USER}"

# Node & Yarn
export FRAPPE_USER FRAPPE_HOME
step_run node.install "${REPO_DIR}/scripts/install_node.sh"

# MariaDB
export MYSQL_ROOT_PASSWORD
step_run mariadb.install "${REPO_DIR}/scripts/install_mariadb.sh"

# Bench via pipx preferred
step_run pip.ensurepipx apt_install pipx || true
if ! command -v pipx >/dev/null 2>&1; then
  warn "pipx not found; using pip system install for bench."
  step_run pip.bench with_retries 5 bash -lc "python3 -m pip install -U pip && python3 -m pip install frappe-bench ansible"
else
  step_run pipx.install with_retries 5 bash -lc "pipx install frappe-bench || pipx reinstall frappe-bench"
  step_run pipx.ansible with_retries 5 bash -lc "pipx install ansible || pipx reinstall ansible || true"
fi

# Bench init
step_run bench.version run_as_user "$FRAPPE_USER" 'bench --version || true'
step_run bench.init run_as_user "$FRAPPE_USER" "bench init frappe-bench --frappe-branch ${FRAPPE_BRANCH}"

# Apps
step_run bench.get_apps run_as_user "$FRAPPE_USER" "cd ~/frappe-bench && bench get-app payments && bench get-app --branch ${FRAPPE_BRANCH} erpnext && bench get-app hrms"

# New site
if [[ -z "${MYSQL_ROOT_PASSWORD:-}" ]]; then
  warn "MYSQL_ROOT_PASSWORD not provided; using the generated one from MariaDB step."
fi
step_run bench.new_site run_as_user "$FRAPPE_USER" "cd ~/frappe-bench && bench new-site ${SITE_NAME} --admin-password \"${ADMIN_PASSWORD}\" --mariadb-root-password \"${MYSQL_ROOT_PASSWORD}\" --no-mariadb-socket"

# Install apps to site
for app in $APPS; do
  step_run "bench.install_app.${app}" run_as_user "$FRAPPE_USER" "cd ~/frappe-bench && bench --site ${SITE_NAME} install-app ${app}"
done

# Enable scheduler & maintenance off
step_run bench.site_flags run_as_user "$FRAPPE_USER" "cd ~/frappe-bench && bench --site ${SITE_NAME} enable-scheduler && bench --site ${SITE_NAME} set-maintenance-mode off"

# Production (optional)
if [[ "${PRODUCTION}" == "yes" ]]; then
  step_run bench.production "${REPO_DIR}/scripts/bench_production.sh"
else
  warn "Skipping production setup. Start dev server with:
  su - ${FRAPPE_USER} -c \"cd ~/frappe-bench && bench start\"
  (Reach at http://SERVER_IP:8000)"
fi

ok "Install complete."
