#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname "$0")/helpers.sh"

: "${FRAPPE_USER:?FRAPPE_USER not set}"

step_run node.nvm_bootstrap run_as_user "$FRAPPE_USER" 'command -v nvm || (curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash)'
# make sure nvm is in profile
append_once "/home/${FRAPPE_USER}/.bashrc" 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
append_once "/home/${FRAPPE_USER}/.profile" 'export NVM_DIR="$HOME/.nvm"; [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'

step_run node.install_18 run_as_user "$FRAPPE_USER" 'source ~/.nvm/nvm.sh && nvm install 18 && nvm alias default 18'
step_run node.verify run_as_user "$FRAPPE_USER" 'source ~/.nvm/nvm.sh && node -v && npm -v'
step_run node.yarn run_as_user "$FRAPPE_USER" 'source ~/.nvm/nvm.sh && npm i -g yarn'
ok "Node 18 + Yarn ready for user $FRAPPE_USER"
