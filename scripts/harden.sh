#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/helpers.sh"

apt_install ufw fail2ban unattended-upgrades apt-listchanges whiptail
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
yes | ufw enable || true

dpkg-reconfigure --priority=low unattended-upgrades

ok "Basic hardening applied (UFW, fail2ban, unattended-upgrades, whiptail)."
