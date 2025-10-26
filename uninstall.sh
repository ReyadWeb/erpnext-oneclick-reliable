#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/scripts/helpers.sh"
require_root

FRAPPE_USER="${FRAPPE_USER:-frappe}"
FRAPPE_HOME="${FRAPPE_HOME:-/home/${FRAPPE_USER}}"

warn "This will remove bench, site, and apps. Press Ctrl+C to abort."
sleep 3

if command -v supervisorctl >/dev/null 2>&1; then
  supervisorctl stop all || true
fi

run_as_user "$FRAPPE_USER" 'rm -rf ~/frappe-bench'
ok "Removed frappe-bench."

# Optional: purge packages (commented):
# apt-get purge -y mariadb-server redis-server nginx supervisor
# apt-get autoremove -y

ok "Uninstall script finished."
