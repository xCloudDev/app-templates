# Gotify — xCloud OneClick template

Self-hosted push-notification server with a REST API. POST messages from scripts/CI/cron, receive them on the web UI, the Android app, or any HTTP client. Single Go binary, SQLite, ~30 MB RAM idle.

## What this template ships

- **Image:** `gotify/server:2.9.1` (pinned)
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `80` proxied as `main`
- **Volume:** `gotify_data:/app/data` (SQLite DB + uploaded notification icons)
- **Database:** SQLite (single-container, no DB sidecar)

## Fields the install form asks for

| Key | Label | Notes |
|---|---|---|
| `admin_user` | Admin Username | Defaults to `admin`. |
| `admin_password` | Admin Password | Auto-generated (24 chars) if left blank. |

## Auto-generated values

None — admin credentials come from the form (with optional auto-fill on the password field).

## What the user gets in the credentials panel

- **URL** — `https://${DOMAIN}`
- **Username** — `${ADMIN_USER}`
- **Password** — `${ADMIN_PASSWORD}`

## First-run

1. Visit `https://${DOMAIN}` and sign in with the admin credentials shown on the credentials page.
2. Click **Apps → Create Application** to register a sender. Each app gets its own token.
3. POST a message to test:
   ```bash
   curl "https://${DOMAIN}/message?token=<APP_TOKEN>" -F "title=Hello" -F "message=It works"
   ```
4. Install the **Android app** from https://gotify.net/clients and point it at your URL with your user token (Users → click your user → CREATE CLIENT).

The default admin credentials from `.env` are **only used on first boot** — they're stored in the SQLite DB and ignored on subsequent restarts. Change the password from the UI after first sign-in for proper hardening.

## Tokens vs users (mental model)

- **User token** — authenticates *receivers* (your phone, browser, desktop client). One per device usually.
- **App token** — authenticates *senders* (your scripts, cron jobs, monitoring tools). One per logical sender so you can revoke individually.
- **Admin user** — manages users, apps, plugins. The user/app token approach means the admin password rarely needs to be entered after setup.

## Reverse-proxy IP forwarding (optional)

By default Gotify shows the docker-network IP in admin logs (because xCloud's nginx terminates upstream). To see real client IPs, set `GOTIFY_SERVER_TRUSTEDPROXIES` post-install — see https://gotify.net/docs/config for the exact array syntax.

## Re-sync / upgrade

The pinned `2.9.1` tag is immutable. To upgrade: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.** Gotify migrations run automatically on container boot.

## Volume backup

Back up `<site-name>_gotify_data` — captures the SQLite database (`gotify.db`) and uploaded notification icons (`images/`).

For a logical SQLite snapshot:
```bash
docker compose exec gotify sqlite3 /app/data/gotify.db ".backup /tmp/gotify.bak"
docker compose cp gotify:/tmp/gotify.bak ./gotify-backup-$(date +%F).bak
```

## Why this template is simple

Gotify is a single static Go binary. The image has no `USER` directive — runs as root, so no chown gymnastics needed. SQLite is the default driver, no external DB. No SMTP, no OAuth, no setup wizard. The only state lives on one named volume.
