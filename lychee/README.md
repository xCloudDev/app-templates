# Lychee — xCloud OneClick template

Self-hosted photo gallery — upload, organize, share. Album-level privacy controls, ImageMagick thumbnails, ffmpeg video transcoding, geotag map view.

## What this template ships

- **Image:** `lycheeorg/lychee:v7.5.4` (pinned)
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `80` (embedded nginx + php-fpm) proxied as `main`
- **Database:** SQLite (single-container, no DB sidecar)
- **Volumes (5):** `lychee_conf` (config + SQLite DB), `lychee_uploads` (originals + thumbnails — **the big one**), `lychee_sym` (symlinks), `lychee_logs` (Laravel logs), `lychee_tmp` (upload scratch)

## Fields the install form asks for

| Key | Label | Notes |
|---|---|---|
| `admin_user` | Admin Username | Defaults to `admin`. |
| `admin_password` | Admin Password | Auto-generated (24 chars) if left blank. |

## Auto-generated values

| Key | Used as | Format |
|---|---|---|
| `app_key` | `APP_KEY` | `base64:<44-char base64 of 32 random bytes>` (Laravel canonical). Required — Lychee's entrypoint refuses to start without it. |

## What the user gets in the credentials panel

- **URL** — `https://${DOMAIN}`
- **Username** — `${ADMIN_USER}`
- **Password** — `${ADMIN_PASSWORD}`

## First-run

1. Visit `https://${DOMAIN}` and sign in with the admin credentials shown on the credentials page.
2. Create albums, drag-drop photos to upload.
3. Configure sharing settings, watermarks, EXIF visibility from **Settings → All Settings**.

The first-run admin-creation wizard is bypassed because we pre-seed `ADMIN_USER` + `ADMIN_PASSWORD` via env. Migrations run automatically via the entrypoint — no post-install script needed.

## Photo upload size limit (important)

xCloud's nginx layer in front of the container enforces a default `client_max_body_size`. Large originals (RAW files, high-res JPEGs from modern cameras) can hit HTTP 413 on upload.

**Fix:** open the **Nginx Customization** page on this site (sidebar → Tools → Nginx Customization) and add a custom rule raising the limit, e.g.:

```
client_max_body_size 200M;
```

200 MB covers most camera RAW files; bump higher if you shoot medium-format.

## Mail (optional)

Lychee uses standard Laravel mail config. Required for password reset, album-share notifications, and signup emails (if you enable public registration). Add to `/var/www/${SITE_NAME}/.env` post-install:

```
MAIL_MAILER=smtp
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=...
MAIL_PASSWORD=...
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME=Lychee
```

Then `docker compose up -d` to apply.

## Disk planning

Photo libraries grow fast. Track the `lychee_uploads` volume — it holds:
- **Originals** (full-res files as uploaded)
- **Thumbnails** (multiple sizes: 200px, 400px, medium, large)
- **Live photo** sidecar files (if you upload iPhone live photos)

Rough sizing: **~1.3× the size of your originals** once thumbnails are generated. A 100 GB original library uses ~130 GB on the volume.

## Re-sync / upgrade

The pinned `v7.5.4` tag is immutable. To upgrade: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.** Lychee runs Laravel migrations automatically on boot, so upgrades within a major version are safe via Redeploy. Across major versions, read the [Lychee changelog](https://github.com/LycheeOrg/Lychee/releases) before bumping.

## Volume backup

Back up all 5 volumes for full DR, but in priority order:
1. **`<site-name>_lychee_uploads`** — your photo originals. The big one. Lose this and your photos are gone.
2. **`<site-name>_lychee_conf`** — config + SQLite DB (album metadata, users, share links).
3. The other three (`sym`, `logs`, `tmp`) are auxiliary — regenerable on first boot if lost.

You can also export the SQLite DB on-demand:
```bash
docker compose exec lychee sqlite3 /conf/database.sqlite ".backup /tmp/lychee.bak"
docker compose cp lychee:/tmp/lychee.bak ./lychee-backup-$(date +%F).bak
```
