#!/usr/bin/env bash
# Interactive installer (self-bootstrapping for curl|bash usage)
set -euo pipefail

# --- minimal root check before sourcing helpers ---
if [[ "$(id -u)" -ne 0 ]]; then
  echo "✖ Please run as root (sudo)." >&2
  exit 1
fi

GITHUB_REPO="ReyadWeb/erpnext-oneclick-reliable"
WORKDIR="/opt/erpnext-oneclick"
mkdir -p "$WORKDIR"

have_cmd(){ command -v "$1" >/dev/null 2>&1; }

# In piped mode (curl|bash) BASH_SOURCE can be empty; handle safely
SELF="${BASH_SOURCE[0]:-}"
if [[ -n "$SELF" ]]; then
  SELF_DIR="$(cd "$(dirname "$SELF")" && pwd)"
else
  SELF_DIR="$(pwd)"
fi
REPO_DIR="$(cd "${SELF_DIR}/.." 2>/dev/null || echo "${SELF_DIR}")"

# If helpers aren’t present, we’re likely running via curl | bash. Bootstrap:
if [[ ! -f "${REPO_DIR}/scripts/helpers.sh" ]]; then
  echo "ℹ Bootstrapping from GitHub…"
  have_cmd curl || { apt-get update -y && apt-get install -y curl ca-certificates; }
  TAR_URL="https://codeload.github.com/${GITHUB_REPO}/tar.gz/refs/heads/main"
  TMPDIR="$(mktemp -d)"
  curl -fsSL "$TAR_URL" | tar -xz -C "$TMPDIR"
  # Find extracted folder (should be <repo>-main)
  BOOT_DIR="$(find "$TMPDIR" -maxdepth 1 -type d -name '*erpnext-oneclick-reliable*' | head -n1)"
  if [[ -z "$BOOT_DIR" ]]; then
    echo "✖ Failed to download repo from $TAR_URL" >&2
    exit 1
  fi
  # Move into WORKDIR for stable path
  rm -rf "${WORKDIR:?}/current"
  mv "$BOOT_DIR" "${WORKDIR}/current"
  REPO_DIR="${WORKDIR}/current"
fi

# Try to keep whiptail happy in minimal consoles
export TERM="${TERM:-xterm-256color}"

# shellcheck disable=SC1091
source "${REPO_DIR}/scripts/helpers.sh"
# shellcheck disable=SC1091
source "${REPO_DIR}/scripts/ui.sh"

require_root
preflight_checks

# Ensure whiptail if we want the pretty UI; fallback still works if install fails
if ! have_cmd whiptail; then
  apt_install whiptail || true
fi

progress "Collecting install details..."

# Defaults
DEF_USER="frappe"
DEF_SITE="erp.local"
DEF_APPS="erpnext hrms payments"
DEF_BRANCH="version-15"

FRAPPE_USER="$(prompt "Frappe User" "Linux username to run bench" "$DEF_USER")"
SITE_NAME="$(prompt "Site Domain / Name" "Use a real domain (example.com) for production or a local name for dev" "$DEF_SITE")"
ADMIN_PASSWORD="$(secret "ERPNext Admin Password" "Password for ERPNext Administrator user")"
while [[ -z "${ADMIN_PASSWORD}" ]]; do
  ADMIN_PASSWORD="$(secret "ERPNext Admin Password" "Password cannot be empty. Try again")"
done
MYSQL_ROOT_PASSWORD="$(secret "MariaDB root password" "If blank, a strong password will be generated")"
APPS="$(prompt "Apps to install" "Space-separated list" "$DEF_APPS")"
FRAPPE_BRANCH="$(prompt "Frappe/ERPNext branch" "Typically version-15" "$DEF_BRANCH")"
PRODUCTION="no"
if [[ "$(confirm "Production Setup" "Configure Supervisor + Nginx and expose on ports 80/443?")" == "yes" ]]; then
  PRODUCTION="yes"
fi

# Basic validations
if [[ "$PRODUCTION" == "yes" ]]; then
  if is_valid_domain "$SITE_NAME"; then
    info "Domain looks valid: $SITE_NAME"
    A_REC="$(resolve_a_record "$SITE_NAME" || true)"
    if [[ -z "${A_REC:-}" ]]; then
      warn "Could not resolve A record for $SITE_NAME. You can continue, but HTTPS will likely fail until DNS propagates."
    else
      ok "Resolved $SITE_NAME to $A_REC"
    fi
  else
    warn "Site name '$SITE_NAME' is not a valid public domain. You can still proceed, but production setup expects a real domain."
  fi
fi

echo
info "Summary:
  FRAPPE_USER=${FRAPPE_USER}
  SITE_NAME=${SITE_NAME}
  APPS=${APPS}
  FRAPPE_BRANCH=${FRAPPE_BRANCH}
  PRODUCTION=${PRODUCTION}
"
if [[ "$(confirm "Proceed" "Begin installation now?")" != "yes" ]]; then
  err "Installation aborted by user."
  exit 1
fi

# Run the real installer from the repo directory we ensured above
set +e
bash "${REPO_DIR}/install.sh" \
  --frappe-user "$FRAPPE_USER" \
  --site-name "$SITE_NAME" \
  --admin-password "$ADMIN_PASSWORD" \
  --apps "$APPS" \
  --frappe-branch "$FRAPPE_BRANCH" \
  --production "$PRODUCTION" \
  ${MYSQL_ROOT_PASSWORD:+--mariadb-root "$MYSQL_ROOT_PASSWORD"}
rc=$?
set -e

if [[ $rc -ne 0 ]]; then
  err "Install failed with exit code $rc."
  echo "Tips:"
  echo "  - Check free RAM (need ~4GB) and disk (need ~40GB)."
  echo "  - If MariaDB failed to secure, ensure no existing root password and rerun."
  echo "  - Inspect /var/log/erpnext-oneclick/install.log, /var/log/nginx/error.log, supervisorctl status."
  exit $rc
else
  ok "Installation completed successfully."
  if [[ "$PRODUCTION" == "yes" ]]; then
    echo "Access your site at: http://$SITE_NAME/"
  else
    echo "Dev server: su - $FRAPPE_USER -c 'cd ~/frappe-bench && bench start' (http://SERVER_IP:8000)"
  fi
fi
