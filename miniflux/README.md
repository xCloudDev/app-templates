# Miniflux — xCloud OneClick template

Minimalist self-hosted RSS reader. Fast, keyboard-driven, mobile-first PWA. Single Go binary backed by Postgres.

## What this template ships

- **Image:** `miniflux/miniflux:2.2.19-distroless` (pinned) — distroless, runs as non-root, has no shell. Statically-linked Go binary with a built-in healthcheck command.
- **Sidecar:** `postgres:17.2-alpine` for the database
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `8080` proxied as `main`
- **Volume:** `miniflux_db_data:/var/lib/postgresql/data` (Postgres only — Miniflux itself is fully stateless)

## Fields the install form asks for

| Key | Label | Notes |
|---|---|---|
| `admin_user` | Admin Username | Defaults to `admin`. |
| `admin_password` | Admin Password | Auto-generated (24 chars) if left blank. |

## Auto-generated values

| Key | Used as | Format |
|---|---|---|
| `db_password` | `POSTGRES_PASSWORD` + `DATABASE_URL` | 24 chars random |

## What the user gets in the credentials panel

- **URL** — `https://${DOMAIN}`
- **Username** — `${ADMIN_USER}`
- **Password** — `${ADMIN_PASSWORD}`

## First-run

1. Visit `https://${DOMAIN}` and sign in with the admin credentials shown on the credentials page.
2. Click **+** in the top bar → **Add subscription** → paste any feed URL (Miniflux discovers RSS/Atom/JSON feeds from a homepage URL too).
3. Optionally install as a PWA — modern mobile browsers offer "Add to Home Screen" from the share menu.
4. Review **Settings → Keyboard shortcuts** for the keyboard-first navigation.

The `RUN_MIGRATIONS=1` and `CREATE_ADMIN=1` env vars are **idempotent** — they're safe to leave at `1` forever:
- Migrations are versioned via a `schema_version` table, no-op when up to date.
- Admin creation logs `Skipping admin user creation because it already exists` on subsequent boots.

You can change the admin password from **Settings → Account** after first login. The `ADMIN_PASSWORD` env var only seeds the *initial* user; UI-changed passwords win over env on every subsequent boot.

## OAuth / OIDC (optional)

Miniflux supports OIDC/Google/GitHub login via env vars (`OAUTH2_PROVIDER`, `OAUTH2_CLIENT_ID`, etc.). All optional — the container boots fine with them absent. To enable, edit `/var/www/${SITE_NAME}/.env` post-install and `docker compose up -d`. Full reference: https://miniflux.app/docs/configuration.html

## SMTP

Miniflux **doesn't send email** — there's nothing to configure. Password reset is via the admin's manual reset, not email.

## Resource use

Idle: Miniflux ~30 MB, Postgres ~200 MB. With 50–100 subscribed feeds polling hourly, expect Miniflux to climb to 80–150 MB and Postgres to 250–400 MB. The 512 MB minimum in the manifest covers conservative real-world use.

## Re-sync / upgrade

The pinned `2.2.19-distroless` and `17.2-alpine` tags are immutable. To upgrade Miniflux: bump `app_version`, re-sync via Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.** Migrations run automatically on boot.

## Volume backup

Back up `<site-name>_miniflux_db_data` — the Postgres data directory holds everything (subscriptions, read state, full-text index, integration tokens).

For an on-demand logical dump:
```bash
docker compose exec db pg_dump -U miniflux miniflux > miniflux-backup-$(date +%F).sql
```

## Why this template fits the catalog cleanly

- **Distroless image, runs as non-root** — minimal attack surface
- **Stateless app container** — only the DB has state, so no chown gymnastics
- **No SMTP env vars at all** — nothing to ship empty (Vaultwarden trap can't apply)
- **Idempotent admin bootstrap** — env-driven first-run, no manual setup wizard
- **Built-in healthcheck binary** — works on the distroless image without wget/curl
- **Official Postgres sidecar** — same `postgres:17.2-alpine` we use elsewhere; cached base layer
