# Redis — xCloud OneClick template

In-memory data store for caching, queues, pub/sub, and fast key-value workloads.

## What this template ships

- **Image:** `redis:8.6-alpine` (pinned)
- **Service class:** `data_service` — no domain, no SSL, raw `${SERVER_IP}:${PORT_REDIS}` connection
- **Port:** container `6379` exposed on host `0.0.0.0:${PORT_REDIS}` (publicly reachable — restrict via firewall before production use)
- **Volume:** `redis_data:/data`
- **Persistence:** AOF (`--appendonly yes`) — every write is fsynced to disk

## Fields the install form asks for

| Key | Label | Notes |
|---|---|---|
| `admin_password` | Redis Password | Auto-generated (24 chars) if blank. |

Redis runs without a username (`AUTH <password>` only) — clients pass the password as the URI password segment.

## Auto-generated values

None — every value comes from the form (with optional auto-fill on the password field).

## What the user gets in the credentials panel

- **Connection String** — `redis://:${ADMIN_PASSWORD}@${SERVER_IP}:${PORT_REDIS}/0`
- **Host / Port / Password**

## First-run

The container starts immediately with AUTH enforced via `--requirepass`. Connect with:

```bash
redis-cli -h ${SERVER_IP} -p ${PORT_REDIS} -a "${ADMIN_PASSWORD}"
# or
redis-cli -u "redis://:${ADMIN_PASSWORD}@${SERVER_IP}:${PORT_REDIS}/0"
```

## Hardening

- **Restrict network access.** Port `${PORT_REDIS}` is bound to `0.0.0.0` so external apps can connect. Lock it down with the host firewall to only known client IPs before exposing to untrusted networks. Unauthenticated open Redis on the internet is one of the most-scanned targets — even with AUTH, restrict the firewall.
- **Use Redis ACLs** for per-app credentials with restricted command sets (Redis 6+):
  ```
  ACL SETUSER app on >appsecret ~app:* +get +set +del
  ```
- **TLS** is not enabled in this template — for production cross-server traffic, terminate TLS at a sidecar proxy (e.g. stunnel) or use Redis 6+ TLS via custom config.

## Re-sync / upgrade

The pinned `8.6-alpine` tag tracks the latest patch within minor 8.6. To upgrade across minors: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up `<site-name>_redis_data` — captures the AOF and any RDB snapshots. For a logical snapshot, force a save first:

```bash
docker compose exec redis redis-cli -a "${REDIS_PASSWORD}" BGSAVE
```

The resulting `dump.rdb` lives inside the volume.
