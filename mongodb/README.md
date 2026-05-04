# MongoDB — xCloud OneClick template

Document-oriented NoSQL database with flexible JSON-like documents.

## What this template ships

- **Image:** `mongo:8.2` (pinned)
- **Service class:** `data_service` — no domain, no SSL, raw `${SERVER_IP}:${PORT_MONGODB}` connection
- **Port:** container `27017` exposed on host `0.0.0.0:${PORT_MONGODB}` (publicly reachable — restrict via firewall before production use)
- **Volume:** `mongodb_data:/data/db`

## Fields the install form asks for

| Key | Label | Notes |
|---|---|---|
| `admin_user` | Root Username | Defaults to `mongoadmin`. |
| `admin_password` | Root Password | Auto-generated (24 chars) if blank. |
| `database_name` | Default Database | Defaults to `app_db`. The root user authenticates against `admin`; `database_name` is created on first connection. |

## Auto-generated values

None — every value comes from the form (with optional auto-fill on the password field).

## What the user gets in the credentials panel

- **Connection String** — `mongodb://${ADMIN_USER}:${ADMIN_PASSWORD}@${SERVER_IP}:${PORT_MONGODB}/${DATABASE_NAME}?authSource=admin`
- **Host / Port / Database / Username / Password**

## First-run

The official `mongo` entrypoint creates the root user from `MONGO_INITDB_ROOT_*` on first boot. The credential database is `admin` — make sure clients pass `authSource=admin` (already in the connection string above).

```bash
mongosh "mongodb://${ADMIN_USER}:${ADMIN_PASSWORD}@${SERVER_IP}:${PORT_MONGODB}/${DATABASE_NAME}?authSource=admin"
```

## Hardening

- **Restrict network access.** Port `${PORT_MONGODB}` is bound to `0.0.0.0` so external apps can connect. Lock it down with the host firewall to only known client IPs before exposing to untrusted networks. Open MongoDB on the public internet is a known target — don't.
- **Create per-app users** instead of using the root account. From `mongosh`:
  ```js
  use app_db
  db.createUser({ user: 'app', pwd: '...', roles: [{ role: 'readWrite', db: 'app_db' }] })
  ```
- **TLS** is not enabled in this template — terminate TLS at the application layer or run a MongoDB TLS-aware proxy in front for production cross-server traffic.

## Re-sync / upgrade

The pinned `8.2` tag tracks the latest patch within minor 8.2. **Major-version upgrades** require setting `setFeatureCompatibilityVersion` after the upgrade — read the MongoDB upgrade notes before bumping `app_version`. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up `<site-name>_mongodb_data` — full WiredTiger storage including indexes and the oplog. For logical backups:

```bash
docker compose exec mongodb mongodump --uri="mongodb://${ADMIN_USER}:${ADMIN_PASSWORD}@127.0.0.1:27017/?authSource=admin" --out=/tmp/dump
docker compose cp mongodb:/tmp/dump ./mongo-backup
```
