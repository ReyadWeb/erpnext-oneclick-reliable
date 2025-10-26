# ERPNext One‑Click (Ubuntu 24.04)

A fast, reproducible installer for **ERPNext v15** on **Ubuntu 24.04 LTS**.

## What you get
- Non‑root **frappe** user (or custom) with sudo
- System packages (Python 3.12 venv, Redis, Node 18 via nvm, Yarn, wkhtmltopdf)
- **MariaDB 10.11** (Ubuntu 24.04 default) tuned for Frappe/ERPNext
- **frappe-bench** with ERPNext (and optional HRMS, Payments)
- Optional production hardening (Supervisor + Nginx with `bench setup production`)
- Idempotent steps (safe to re‑run)

> **Video reference:** If you prefer a walkthrough, there are many community videos. This repo follows the modern 24.04 flow and automates common pitfalls.

---

## Quick Start (One command – interactive & validated)
```bash
# On a fresh Ubuntu 24.04 server (run as root or a sudo user)
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB/erpnext-oneclick/main/scripts/install_interactive.sh | bash
```
> Replace `YOUR_GITHUB` with your namespace after you push this repo.

---

## Custom / Offline
1) Clone & edit config in `.env` (copy from `.env.example`)
```bash
git clone https://github.com/YOUR_GITHUB/erpnext-oneclick.git
cd erpnext-oneclick
cp .env.example .env
# edit values
sudo bash install.sh --env .env
```
2) After install, ERPNext dev server is at `http://SERVER_IP:8000` (if `bench start`).
3) For production:
```bash
sudo bash scripts/bench_production.sh
```

---

## Defaults
- **FRAPPE_USER:** frappe
- **SITE_NAME:** erp.local
- **ADMIN_PASSWORD:** admin
- **MYSQL_ROOT_PASSWORD:** generated if not set
- **APPS:** erpnext hrms payments

Change them in `.env` or pass flags (see below).

---

## Flags
```bash
sudo bash install.sh   --frappe-user frappe   --site-name example.local   --admin-password "StrongPass!"   --mariadb-root "StrongDBPass!"   --apps "erpnext hrms payments"   --production yes   --env .env
```
- `--production yes` runs Supervisor/Nginx via bench.
- `--env` loads variables from an env file (values there override defaults).

---

## Uninstall (danger)
```bash
sudo bash uninstall.sh
```

---

## Troubleshooting
- **wkhtmltopdf**: ERPNext needs **0.12.x with patched Qt**. Ubuntu’s package is usually OK. If PDFs look off, consider a pinned 0.12.6 build for your distro.
- **MariaDB**: Ubuntu 24.04 ships **10.11** (LTS). Ensure `utf8mb4` + `innodb_file_per_table=1`. We create `/etc/mysql/mariadb.conf.d/erpnext.cnf`.
- If `bench start` crashes, check `logs/` inside the bench or `journalctl -u supervisor` after production setup.

---

## License
MIT


---

## Non-interactive (CI/automation)
Use flags or an `.env` file:
```bash
sudo bash install.sh --env .env --production yes
```
