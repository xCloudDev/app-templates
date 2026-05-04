# 2FAuth — xCloud OneClick template

Self-hosted, single-user 2FA / TOTP code manager. Stores authenticator secrets so you can generate codes from a browser instead of an app.

## What this template ships

- **Image:** `2fauth/2fauth:6.1.3` (pinned)
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `8000` proxied as `main`
- **Volume:** `twofauth_data:/2fauth` (SQLite DB, sessions, logs — single path covers all state)
- **Database:** SQLite (file-backed, no sidecar)

## Fields the install form asks for

None — the user picks a domain; the first person to visit it and register becomes the only admin.

## Auto-generated values

| Key | Used as | Format |
|---|---|---|
| `app_key` | `APP_KEY` | 32 chars random alphanumeric. **Note:** 2FAuth's `APP_KEY` is a raw 32-char string, NOT Laravel's `base64:<...>` format. |

## What the user gets in the credentials panel

- **URL** — `https://${DOMAIN}`

## First-run

1. Visit `https://${DOMAIN}` and click **Register**.
2. The first account created becomes the (only) admin. By design, 2FAuth refuses to create more than one user — this is a personal-use tool.
3. Add 2FA accounts from the dashboard: scan a QR code, paste an OTPAuth URI, or enter the secret manually.

No setup wizard, no migrations to run by hand — the entrypoint applies the schema on first boot.

## ⚠️ Critical: back up `APP_KEY`

`APP_KEY` is the master key. If you enable **per-account secret encryption** (Settings → Account → Encryption, off by default), the stored TOTP secrets are encrypted with a key derived from `APP_KEY`. **Lose `APP_KEY`, lose every stored secret** — there's no recovery path.

Two-line backup:
```bash
ssh into the server
grep '^APP_KEY=' /var/www/${SITE_NAME}/.env
```

Save that line in your password manager (or wherever you keep recovery codes). For full disaster recovery you need both:
- the `APP_KEY` value, AND
- the contents of the `<site-name>_twofauth_data` Docker volume (especially `database.sqlite`)

`APP_PREVIOUS_KEYS` is supported for rotation — see [2FAuth's docs](https://docs.2fauth.app/) if you ever need to change the key without losing existing secrets.

## Mail (optional)

The shipped `.env` uses `MAIL_MAILER=log` so the container boots without SMTP. To enable password-reset and WebAuthn email flows, edit `/var/www/${SITE_NAME}/.env` post-install:

```
MAIL_MAILER=smtp
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=...
MAIL_PASSWORD=...
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME=2FAuth
```

Then `docker compose up -d` to apply.

## WebAuthn

WebAuthn (passkey login for 2FAuth itself, not for the stored TOTP accounts) is enabled by default and tied to your domain. As long as the site is served over HTTPS at the domain in `APP_URL`, no further config is needed. If you change the domain post-install, also update `APP_URL` and `WEBAUTHN_HOMEPAGE` in `.env` and redeploy.

## Re-sync / upgrade

The pinned `6.1.3` tag is immutable. To upgrade: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.** 2FAuth runs migrations automatically on container boot, so upgrades within a major version are safe to perform via Redeploy.

## Volume backup

Back up `<site-name>_twofauth_data` — captures the SQLite database (`database.sqlite`), session files, and logs. Combined with the `APP_KEY` value, that's everything you need to restore.
