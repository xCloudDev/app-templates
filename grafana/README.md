# Grafana — xCloud OneClick template

Observability and dashboard platform for metrics, logs, traces, and alerting.

## What this template ships

- **Image:** `grafana/grafana:12.4` (pinned)
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `3000` proxied as `main`
- **Volume:** `grafana_data:/var/lib/grafana` (dashboards, datasources, users, plugins, internal SQLite)

## Fields the install form asks for

| Key | Label | Notes |
|---|---|---|
| `admin_user` | Admin Username | Defaults to `admin`. |
| `admin_password` | Admin Password | Auto-generated (24 chars) if left blank. |

## Auto-generated values

None — credentials come from the form.

## What the user gets in the credentials panel

- **Username** — `${ADMIN_USER}`
- **Password** — `${ADMIN_PASSWORD}`

## First-run

1. Visit `https://${DOMAIN}` and sign in with the admin credentials shown on the credentials page.
2. Add datasources from **Connections → Data sources** (Prometheus, Loki, MySQL, etc).
3. Public sign-ups are disabled by default (`GF_USERS_ALLOW_SIGN_UP=false`). Add users from **Administration → Users**.

## SMTP (optional)

Required for invite emails, password reset, and alert notifications. Add to `/var/www/${SITE_NAME}/.env`:

```
GF_SMTP_ENABLED=true
GF_SMTP_HOST=smtp.example.com:587
GF_SMTP_USER=...
GF_SMTP_PASSWORD=...
GF_SMTP_FROM_ADDRESS=noreply@example.com
GF_SMTP_FROM_NAME=Grafana
```

Then `docker compose up -d` to apply.

## Hardening

- **Rotate the admin password** from the UI after first login (the bootstrap password from the credentials panel only gates the first sign-in).
- **Disable anonymous access** (already off by default — `GF_USERS_ALLOW_SIGN_UP=false`).
- **Configure auth providers** (LDAP, OAuth, SAML) via additional `GF_AUTH_*` env vars.

## Re-sync / upgrade

The pinned `12.4` tag tracks the latest patch within minor 12.4. To upgrade across minors: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up `<site-name>_grafana_data` — captures dashboards, datasource configs, users, alert rules, and the internal SQLite database.
