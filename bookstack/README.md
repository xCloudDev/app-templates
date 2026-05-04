# BookStack — xCloud OneClick template

Self-hosted documentation/wiki platform. Books → chapters → pages, WYSIWYG editor, full-text search.

## What this template ships

- **Image:** `lscr.io/linuxserver/bookstack:25.05` (pinned)
- **Sidecar:** `lscr.io/linuxserver/mariadb:11.4.5` for the database
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `80` proxied as `main`
- **Volumes:** `bookstack_config:/config` (uploads, config, generated `.env`), `bookstack_db:/config` (MariaDB data)

## Fields the install form asks for

None.

## Auto-generated values

| Key | Used as | Format |
|---|---|---|
| `app_key` | `APP_KEY` | `base64:<44-char base64 of 32 random bytes>` (Laravel canonical) |
| `db_root_password` | `MYSQL_ROOT_PASSWORD` | 24 chars random |
| `db_name` | `MYSQL_DATABASE`, `DB_DATABASE` | `bookstack_xxxxxxxx` |
| `db_user` | `MYSQL_USER`, `DB_USERNAME` | `bookstack_xxxxxxxx` |
| `db_password` | `MYSQL_PASSWORD`, `DB_PASSWORD` | 24 chars random |

## What the user gets in the credentials panel

- **BookStack URL** — `https://${DOMAIN}`
- **Default admin email** — `admin@admin.com`
- **Default admin password** — `password`

## First-run

1. Visit `https://${DOMAIN}`.
2. Sign in with `admin@admin.com` / `password`.
3. **Immediately** go to **Settings → Users → Edit admin** and change both the email and the password.

The linuxserver entrypoint runs `php artisan migrate --force` automatically on first start — no post-install script needed.

## SMTP (optional)

Pre-declared as empty placeholders in `.env`. Required for password reset, invitations, and notifications. Edit the rendered `.env` post-install and `docker compose up -d` to apply:

```
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=...
MAIL_PASSWORD=...
MAIL_ENCRYPTION=tls
MAIL_FROM=noreply@example.com
```

## Re-sync / upgrade

The `25.05` and `11.4.5` tags are pinned to specific minor versions. To upgrade BookStack: bump `app_version` in the manifest, re-sync via Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up both Docker volumes:
- `<site-name>_bookstack_config` — application data, uploads, generated `.env`
- `<site-name>_bookstack_db` — MariaDB data

`APP_KEY` is xCloud-managed and persists in `oneclick_installations.generated_values`, so even a full volume loss preserves the encryption key as long as the xCloud install record exists.
