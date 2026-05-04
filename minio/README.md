# MinIO — xCloud OneClick template

S3-compatible object storage. Single-binary, single-tenant, ready in seconds.

## What this template ships

- **Image:** `quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z` (pinned)
- **Service class:** `data_service` (no public domain — accessed via `${SERVER_IP}:${PORT}`)
- **Ports:** S3 API on `${PORT_S3}` → container `9000`, console on `${PORT_CONSOLE}` → container `9001`
- **Volume:** `minio_data:/data`

## Fields the install form asks for

| Field | Required | Default | Notes |
|---|---|---|---|
| Root user (access key) | yes | `minioadmin` | min 3 chars |
| Root password (secret key) | yes | auto-generated 24 chars | min 8 chars |

## What the user gets in the credentials panel

- **Console URL** — `http://${SERVER_IP}:${PORT_CONSOLE}` (browser UI)
- **S3 API endpoint** — `http://${SERVER_IP}:${PORT_S3}` (for SDKs)
- **Access key / Secret key** — what was filled in / generated above

## First-run

No initialization needed. The container is ready immediately after `docker compose up -d`. Buckets are created on demand from the console or via `mc` CLI.

## Re-sync / upgrade

The pinned `RELEASE.*` tag is immutable. To upgrade, bump `app_version` in the manifest, re-sync the template in Nova, and the next install pulls the new image. **Existing installs stay on their pinned SHA.**

## Security notes

- The console is **HTTP only** by default. Don't expose it to the public internet without a reverse proxy + TLS in front.
- Both ports bind to `0.0.0.0` — anyone on the internet can attempt connections. Mitigations: random ephemeral ports, strong generated secret key. Consider firewall allowlists if hardening is needed.
- The `MINIO_BROWSER_REDIRECT_URL` and `MINIO_SERVER_URL` environment variables are intentionally **not set**. If you put MinIO behind a public-facing reverse proxy, set them in the rendered `.env` post-install.

## Volume backup

Back up `/var/lib/docker/volumes/<site-name>_minio_data/_data/` for full state including buckets and metadata.
