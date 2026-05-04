# MariaDB — xCloud OneClick template

Open-source relational database, MySQL-compatible drop-in. Standalone instance for application workloads.

## What this template ships

- **Image:** `mariadb:12.2` (pinned)
- **Service class:** `data_service` — no domain, no SSL, raw `${SERVER_IP}:${PORT_MARIADB}` connection
- **Port:** container `3306` exposed on host `0.0.0.0:${PORT_MARIADB}` (publicly reachable — restrict via firewall before production use)
- **Volume:** `mariadb_data:/var/lib/mysql`

## Fields the install form asks for

| Key | Label | Group | Notes |
|---|---|---|---|
| `admin_user` | App Username | Credentials | Defaults to `mariadb`. |
| `admin_password` | App Password | Credentials | Auto-generated (24 chars) if blank. |
| `database_name` | App Database | Credentials | Defaults to `app_db`. |
| `root_password` | Root Password | Advanced | Auto-generated (24 chars) if blank. |

The "App" credentials are what your application connects with. The root password is reserved for maintenance and backups.

## Auto-generated values

None — every value comes from the form (with optional auto-fill on password fields).

## What the user gets in the credentials panel

- **Connection String** — `mysql://${ADMIN_USER}:${ADMIN_PASSWORD}@${SERVER_IP}:${PORT_MARIADB}/${DATABASE_NAME}`
- **Host / Port / Database / App Username / App Password**
- **Root Password (Advanced)** — masked, copyable

## First-run

The official MariaDB entrypoint creates the app database, app user, and grants on first boot from the `MARIADB_*` env vars — no post-install step needed. Connect immediately with the credentials on the panel.

```bash
mysql -h ${SERVER_IP} -P ${PORT_MARIADB} -u ${ADMIN_USER} -p ${DATABASE_NAME}
```

## Hardening

- **Restrict network access.** Port `${PORT_MARIADB}` is bound to `0.0.0.0` so external apps can connect. Lock it down with the host firewall to only known client IPs before exposing to untrusted networks.
- **Use the app user**, not root, in your application connection string.
- **Rotate the root password** if you suspect leakage — it's stored on `oneclick_installations.generated_values` (encrypted).

## Re-sync / upgrade

The pinned `12.2` tag tracks the latest patch within minor 12.2. **Major-version upgrades** (e.g. 11.x → 12.x) require running `mariadb-upgrade` after replacing the container — read the MariaDB upgrade notes before bumping `app_version`. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up `<site-name>_mariadb_data` — full data directory including system tables, user grants, and InnoDB tablespaces. For logical backups, run `mariadb-dump` against the live container:

```bash
docker compose exec mariadb mariadb-dump -uroot -p"${MARIADB_ROOT_PASSWORD}" --all-databases > backup.sql
```
