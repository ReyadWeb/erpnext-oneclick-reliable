#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/helpers.sh"

apt_install mariadb-server
systemctl enable --now mariadb

MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-}"
if [[ -z "${MYSQL_ROOT_PASSWORD}" ]]; then
  MYSQL_ROOT_PASSWORD="$(tr -dc 'A-Za-z0-9!@#$%_+=' </dev/urandom | head -c 20)"
  export MYSQL_ROOT_PASSWORD
  warn "Generated MySQL root password (store safely): ${MYSQL_ROOT_PASSWORD}"
fi

# Secure install (idempotent)
with_retries 5 bash -lc "mysql --user=root -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; FLUSH PRIVILEGES;\" " || true
with_retries 5 bash -lc "mysql -uroot -p'${MYSQL_ROOT_PASSWORD}' -e \"DELETE FROM mysql.user WHERE User=''; DROP DATABASE IF EXISTS test; DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'; FLUSH PRIVILEGES;\" " || true

# ERPNext recommended charset/collation + mode
cat >/etc/mysql/mariadb.conf.d/erpnext.cnf <<'CNF'
[mysqld]
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
innodb-file-per-table = 1
sql-mode=
CNF

systemctl restart mariadb

# Version info
VER="$(mysql -Nse 'SELECT VERSION()' -uroot -p"${MYSQL_ROOT_PASSWORD}" || true)"
info "MariaDB version: ${VER:-unknown}"
ok "MariaDB installed and configured."
