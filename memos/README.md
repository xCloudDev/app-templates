# Memos — xCloud OneClick template

Lightweight self-hosted note-taking and knowledge-base app. Markdown-first, public/private posts, tags, daily-review style. Single Go binary, SQLite, ~50 MB RAM idle.

## What this template ships

- **Image:** `neosmemo/memos:0.28.0` (pinned — bare semver, **not** `v0.28.0`)
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `5230` proxied as `main`
- **Volume:** `memos_data:/var/opt/memos` (SQLite DB + uploaded blobs — single path covers all state)
- **Database:** SQLite (single-container, no DB sidecar)

## Fields the install form asks for

None — the user picks a domain; the first person to register becomes the workspace Host (admin).

## Auto-generated values

None — Memos doesn't require any pre-shared secrets at install time.

## What the user gets in the credentials panel

- **URL** — `https://${DOMAIN}`

## First-run

1. Visit `https://${DOMAIN}/auth` and click **Sign up**.
2. The first account created becomes the workspace **Host** — full admin privileges.
3. **Important:** after signing in, immediately go to **Settings → Workspace** and toggle **Disable user signup** to prevent anyone else from registering. Without this, anyone who hits the URL can create an account.

No setup wizard, no migrations to run by hand — Memos applies the SQLite schema on first boot.

## SMTP / OAuth / SSO (optional)

All optional integrations are configured **at runtime via the admin UI**, not through environment variables. After signing in as Host:

- **SMTP** — Settings → Workspace → SMTP. Enables password-reset emails and notifications.
- **OAuth / SSO** — Settings → Workspace → Identity Provider. Add Google, GitHub, OIDC providers.
- **Storage** — Settings → Workspace → Storage. Switch from local filesystem to S3-compatible backends if needed.

This means **no SMTP env-var trap** — the container starts fine without any mail config, you add it when ready.

## Re-sync / upgrade

The pinned `0.28.0` tag is immutable. To upgrade: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.**

⚠️ **Don't skip multiple major versions.** Memos has occasional migration issues across non-adjacent majors. Upgrade incrementally: `0.28 → 0.29 → 0.30`, not `0.28 → 0.31`.

## Volume backup

Back up `<site-name>_memos_data` — captures everything: SQLite database (`memos_prod.db`), uploaded blobs (`assets/`), and any optional `memos.env` overrides. One named volume covers the entire install.

For an on-demand SQLite snapshot:

```bash
docker compose exec memos sqlite3 /var/opt/memos/memos_prod.db ".backup /tmp/memos.bak"
docker compose cp memos:/tmp/memos.bak ./memos-backup-$(date +%F).bak
```

## Why this template is simple

Memos is a single Go binary with embedded SQLite — no PHP runtime, no PHP-FPM, no nginx-in-the-container, no Apache mod_rewrite. The container's entrypoint chowns the data directory to its own runtime user before dropping privileges, so named Docker volumes work without special host preparation.
