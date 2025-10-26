#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/scripts/helpers.sh"
require_root

FRAPPE_USER="${FRAPPE_USER:-frappe}"
FRAPPE_HOME="${FRAPPE_HOME:-/home/${FRAPPE_USER}}"

warn "This will remove bench, site, and apps. Press Ctrl+C to abort."
sleep 3

if systemctl is-active --quiet supervisor; then
  supervisorctl stop all || true
fi

su - "$FRAPPE_USER" -c "bash -lc 'rm -rf ~/frappe-bench'"
ok "Removed frappe-bench."

# Optional: purge packages (commented by default)
# apt-get purge -y mariadb-server redis-server nginx supervisor
# apt-get autoremove -y

ok "Uninstall script finished."
