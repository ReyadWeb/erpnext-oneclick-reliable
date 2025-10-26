#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/helpers.sh"

require_root

FRAPPE_USER="${FRAPPE_USER:-frappe}"
FRAPPE_HOME="${FRAPPE_HOME:-/home/${FRAPPE_USER}}"
cd "$FRAPPE_HOME/frappe-bench"

command -v bench >/dev/null 2>&1 || export PATH="/usr/local/bin:$PATH"

step_run bench.production_setup bench setup production "$FRAPPE_USER"
step_run bench.nginx_conf bench setup nginx
if command -v nginx >/dev/null 2>&1; then
  nginx -t && systemctl reload nginx || warn "Nginx test failed; check /etc/nginx/sites-available"
fi

if command -v supervisorctl >/dev/null 2>&1; then
  supervisorctl reread || true
  supervisorctl update || true
  supervisorctl restart all || true
  supervisorctl status || true
fi

ok "Production setup done. Access your site via http://SERVER_IP/"
