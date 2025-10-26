# Changelog

## 0.2.0 (Reliable Edition)
- Idempotent steps with markers and resume support
- Global logging to /var/log/erpnext-oneclick/install.log
- apt lock/retry handling, exponential backoff
- Preflight checks, swap auto-create for low RAM
- Hardened Node/NVM/Yarn, MariaDB secure config
- Production validation (nginx -t, supervisor status)
- Interactive wizard with whiptail fallback and DNS hints

## 0.1.0
- Initial release
