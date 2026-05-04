# Ghost — xCloud OneClick template

Open-source publishing platform for blogs, memberships, newsletters, and creator websites.

## What this template ships

- **Image:** `ghost:6-alpine` (pinned to major version 6)
- **Sidecar:** `mysql:8.4` for the database
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `2368` proxied as `main`
- **Volumes:** `ghost_content:/var/lib/ghost/content` (themes, images, settings DB, members), `ghost_db:/var/lib/mysql` (MySQL data)

## Fields the install form asks for

None.

## Auto-generated values

| Key | Used as | Format |
|---|---|---|
| `db_name` | `database__connection__database`, `MYSQL_DATABASE` | `ghost_xxxxxxxx` |
| `db_user` | `database__connection__user`, `MYSQL_USER` | `ghost_xxxxxxxx` |
| `db_password` | `database__connection__password`, `MYSQL_PASSWORD` | 24 chars random |
| `db_root_password` | `MYSQL_ROOT_PASSWORD` | 24 chars random |

## What the user gets in the credentials panel

- **Site URL** — `https://${DOMAIN}`
- **Admin URL** — `https://${DOMAIN}/ghost/`
- **Database Name / User / Password** — surfaced in case of CLI access

## First-run

1. Visit `https://${DOMAIN}/ghost/` and click **Create your account**. The first signup becomes the site owner.
2. Configure title, description, and theme from **Settings**.

Ghost migrations run automatically on container boot — no post-install script needed.

## Mail (optional)

Ghost requires SMTP for member signup magic links, newsletters, and admin invites. Add the Ghost mail config keys to `/var/www/${SITE_NAME}/.env`:

```
mail__transport=SMTP
mail__options__host=smtp.example.com
mail__options__port=587
mail__options__service=Mailgun
mail__options__auth__user=...
mail__options__auth__pass=...
mail__from=noreply@example.com
```

Then `docker compose up -d` to apply.

## Re-sync / upgrade

The `6-alpine` and `8.4` tags track the latest patch within their major. To upgrade Ghost to a new major: bump `app_version` in the manifest, re-sync via Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.**

## Volume backup

Back up both Docker volumes:
- `<site-name>_ghost_content` — themes, images, members data, settings
- `<site-name>_ghost_db` — MySQL data
