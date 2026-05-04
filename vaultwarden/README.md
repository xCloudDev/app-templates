# Vaultwarden — xCloud OneClick template

Self-hosted Bitwarden-compatible password manager. Single container, SQLite-backed, ~50MB RAM.

## What this template ships

- **Image:** `vaultwarden/server:1.32.7-alpine` (pinned)
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `80` proxied as `main`
- **Volume:** `vaultwarden_data:/data` (SQLite DB, attachments, sends, JWT keys, icon cache)

## Fields the install form asks for

None. The user picks a domain; everything else is auto-generated.

## Auto-generated values

| Key | Used as | Notes |
|---|---|---|
| `admin_token` | `ADMIN_TOKEN` | 48-char random alphanumeric. Plain-text in v1. |

## What the user gets in the credentials panel

- **Vault URL** — `https://${DOMAIN}`
- **Admin panel URL** — `https://${DOMAIN}/admin`
- **Admin token** — surfaced once at install time (also persisted in xCloud's installation record)

## First-run

1. Visit `https://${DOMAIN}` and click **Create Account**. The first registration is just a regular user — this is your account.
2. After your account is created, lock the door:
   ```bash
   ssh into the server
   cd /var/www/${SITE_NAME}
   sed -i 's/SIGNUPS_ALLOWED=true/SIGNUPS_ALLOWED=false/' .env
   docker compose up -d
   ```
3. To use the `/admin` panel (manage all users, change config without restart): visit `https://${DOMAIN}/admin` and paste the admin token.

## SMTP (optional)

The shipped `.env` has empty `SMTP_*` placeholders. SMTP is needed for:
- Password reset emails
- Invitations
- Email-based 2FA
- New-device notifications

Edit the rendered `.env` post-install and `docker compose up -d` to apply.

## Hardening recommendations

- **Rotate `ADMIN_TOKEN` to an Argon2 hash:**
  ```bash
  docker compose exec vaultwarden /vaultwarden hash
  ```
  Replace the plain-text value in `.env` with the produced hash and restart.
- **Disable WebSocket** if your reverse proxy doesn't handle `Upgrade` headers (we do, so leave it on).

## Re-sync / upgrade

The pinned `1.32.7-alpine` tag is immutable. To upgrade, bump `app_version` in the manifest, re-sync the template in Nova, and the next install pulls the new image. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up `/var/lib/docker/volumes/<site-name>_vaultwarden_data/_data/` for full state. The `rsa_key.*` files are JWT signing keys — losing them invalidates all active sessions but doesn't destroy vault contents.
