# PostgreSQL — xCloud OneClick template

Advanced open-source relational database. Standalone instance for application workloads.

## What this template ships

- **Image:** `postgres:17-alpine` (pinned to major version 17)
- **Service class:** `data_service` — no domain, no SSL, raw `${SERVER_IP}:${PORT_POSTGRES}` connection
- **Port:** container `5432` exposed on host `0.0.0.0:${PORT_POSTGRES}` (publicly reachable — restrict via firewall before production use)
- **Volume:** `pgdata:/var/lib/postgresql/data`

## Fields the install form asks for

| Key | Label | Notes |
|---|---|---|
| `admin_user` | Superuser Username | Defaults to `postgres`. |
| `admin_password` | Superuser Password | Auto-generated (24 chars) if blank. |
| `database_name` | Default Database | Defaults to `default_db`. |

## Auto-generated values

None — every value comes from the form (with optional auto-fill on the password field).

## What the user gets in the credentials panel

- **Connection String** — `postgresql://${ADMIN_USER}:${ADMIN_PASSWORD}@${SERVER_IP}:${PORT_POSTGRES}/${DATABASE_NAME}`
- **Host / Port / Database / Username / Password**

## First-run

The official `postgres` entrypoint creates the superuser, default database, and grants from `POSTGRES_*` on first boot — no post-install step needed.

```bash
psql "postgresql://${ADMIN_USER}:${ADMIN_PASSWORD}@${SERVER_IP}:${PORT_POSTGRES}/${DATABASE_NAME}"
```

## Hardening

- **Restrict network access.** Port `${PORT_POSTGRES}` is bound to `0.0.0.0` so external apps can connect. Lock it down with the host firewall to only known client IPs before exposing to untrusted networks.
- **Create per-app roles** instead of using the superuser. From `psql`:
  ```sql
  CREATE ROLE app LOGIN PASSWORD '...';
  GRANT CONNECT ON DATABASE default_db TO app;
  GRANT USAGE ON SCHEMA public TO app;
  GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app;
  ```
- **TLS** is not enabled in this template — terminate TLS at the application layer or run an SSL-aware proxy in front for production cross-server traffic.

## Re-sync / upgrade

The pinned `17-alpine` tag tracks the latest patch within major 17. **Major-version upgrades** (e.g. 16 → 17) require running `pg_upgrade` after replacing the container — read the Postgres upgrade notes before bumping `app_version`. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up `<site-name>_pgdata` — full data directory including indexes, WAL, and configuration. For logical backups:

```bash
docker compose exec postgres pg_dumpall -U "${POSTGRES_USER}" > backup.sql
```
