# xCloud OneClick App Templates

Source of truth for every OneClick app in the xCloud catalog. Each top-level folder is one template; a folder becomes installable once an admin registers it in the xCloud Nova panel and the catalog row is flipped active.

```
app-templates/
├── README.md                  # this file
├── bookstack/
│   ├── README.md              # per-app authoring notes
│   └── .xcloud/
│       ├── .xcloud-config.yaml
│       ├── docker-compose.yml
│       ├── .env
│       └── assets/icon.png
├── chatwoot/
│   └── ...
├── ghost/
└── ...
```

xCloud only reads files inside each app's `.xcloud/` folder — anything else (this README, per-app READMEs, license files) is invisible to the runtime. Path-scoped commit SHAs are pinned per template, so editing one app never moves another's pin.

---

# Authoring an xCloud OneClick Template

A step-by-step guide for adding a new app to the xCloud OneClick catalog.

xCloud ships one runtime today — `docker_compose` on a `docker_nginx` server. Templates that need a one-shot bootstrap step (like Chatwoot's `rails db:chatwoot_prepare`) declare lifecycle scripts that run before/after the main install. Future runtimes (`node`, `php`) will share the same authoring contract.

This guide uses **Ghost** as the simple web-app running example and **Chatwoot** as the lifecycle running example. Both ship in the v1 catalog.

---

## Part 1: The Mental Model

Three boundaries worth understanding before writing code:

1. **xCloud vs you.** xCloud reads files from a fixed `.xcloud/` folder in your repo, parses the YAML manifest at admin-add time, and at site-creation time fetches secondary files (compose, env, lifecycle scripts) at the **commit SHA** that was pinned when the admin added or re-synced the template.

2. **Repo = authoring source. DB = runtime source.** An admin pastes your repo URL into Nova; xCloud resolves `main` to a commit SHA, fetches `.xcloud/.xcloud-config.yaml`, validates it, and stores it as a catalog row keyed to that SHA. New customer installs of your template fetch the secondary files at that pinned SHA — so two installs of the same template version always get identical content. A "Re-sync" Nova action re-resolves the SHA when you ship a change. Rollouts are auditable and reversible.

3. **Service class** describes the *app's shape* (`web_app` needs a domain + SSL; `data_service` doesn't). **Stack** describes the *server* (`docker_nginx` is the only one that runs templates today).

### What xCloud does

- Reads `.xcloud/.xcloud-config.yaml` from your repo when an admin registers the template URL in Nova. Resolves the repo's default-branch HEAD to a commit SHA via the GitHub API and pins everything to that SHA.
- Persists the parsed manifest into `oneclick_templates`, with the resolved SHA stored in `manifest._xcloud.repo_commit_sha`.
- At site-creation time: fetches `.xcloud/docker-compose.yml`, `.xcloud/.env`, and any declared lifecycle scripts from `https://raw.githubusercontent.com/{org}/{repo}/{sha}/.xcloud/...`.
- Stores the compose **verbatim**; renders the `.env` by substituting `${VAR}` references against the install context (form fields, generated values, ports, system vars), with each substituted value shell-quoted.
- Writes both files to `/var/www/{site}/` on the customer server, runs `docker compose pull && docker compose up -d`. Compose reads `.env` natively and substitutes `${VAR}` into `compose.yml` at run time.
- For lifecycle bash: re-fetches at the pinned SHA inside the install Job, wraps each script with `set -a; source /var/www/{site}/.env; set +a` so `$VAR` works natively, runs over SSH. Pre fails → install aborts; post fails → install marked `post_install_failed`, compose stays running for inspection.
- Surfaces Docker's container state on the site overview page from the latest server-monitor snapshot.
- Runs lifecycle actions on existing installs: Start / Stop / Restart / Redeploy / Delete.

### What xCloud does NOT do

- **Build your image.** It just pulls whatever your compose template references.
- **Run arbitrary code from your repo on customer servers.** Only the files declared in your manifest are fetched — nothing else in your repo is read.
- **Validate that your image works.** Test locally before publishing.
- **Re-render against the latest manifest after install.** Each install is pinned to the SHA at install time. Updating templates only affects future installs (until you re-sync).
- **Persist rendered scripts in the DB.** Compose + `.env` go to disk; lifecycle bash travels in-memory through the Task constructor at run time.

---

## Part 2: Repo Layout

Every template folder follows the same `.xcloud/` convention:

```
your-template/
├── README.md                  # author-controlled; ignored by xCloud
├── LICENSE                    # author-controlled; ignored by xCloud
└── .xcloud/
    ├── .xcloud-config.yaml    # the manifest — fixed filename, fixed location
    ├── docker-compose.yml     # path declared in manifest.files.compose
    ├── .env                   # path declared in manifest.files.env — single source of truth for env vars
    ├── assets/
    │   └── icon.png           # path declared in manifest.icon
    └── scripts/
        ├── pre-install.sh     # path declared in manifest.lifecycle.pre_install.fetch
        └── post-install.sh    # path declared in manifest.lifecycle.post_install.fetch
```

Every path in the manifest's `files.*`, `icon`, and `lifecycle.*.fetch` is **relative to `.xcloud/`** — authors never write `.xcloud/` themselves. Anything outside `.xcloud/` (your own README, source code, marketing assets) is invisible to xCloud.

---

## Part 3: The Single-Source-of-Truth Contract

This is the most important rule:

> **Every variable referenced in `compose.yml` or your lifecycle bash must be declared as a key in `.env`.**

`.env` is the source of truth. The `.env` you ship in the repo can:
1. Set static literals: `RAILS_ENV=production`
2. Pull in xCloud context with `${CONTEXT_VAR}` references: `DB_PASSWORD=${DB_PASSWORD}`

xCloud renders the `.env` (substitutes context refs into literals), writes it to `/var/www/{site}/.env`, and Compose reads it natively for `${VAR}` interpolation in `compose.yml`. Bash scripts source the same file.

### Available context variables

| `${VAR}` | Source |
|---|---|
| `${SITE_NAME}` | The Site's name (the customer-chosen domain or auto-generated slug for data services). |
| `${SITE_USER}` | The Site's system user (used for path/permission ops). |
| `${DOMAIN}` | Same as `SITE_NAME`. |
| `${SERVER_IP}` | The customer's server public IP. |
| `${PORT_<KEY>}` | Allocated **host** port for each declared port (e.g., `${PORT_MAIN}`, `${PORT_REDIS}`). |
| `${<FIELD_KEY>}` | Each form field by key, uppercased (e.g., `${ADMIN_EMAIL}`). |
| `${<GENERATED_KEY>}` | Each generated value by key, uppercased (e.g., `${DB_PASSWORD}`). |

**Reserved names** — author-declared `fields[].key`, `generated_values.<key>`, and `ports.<key>` cannot collide with these (case-insensitive): `SITE_NAME`, `SITE_USER`, `DOMAIN`, `SERVER_IP`. Additionally, `fields[].key` and `generated_values.<key>` cannot start with `PORT_` because that namespace is auto-injected from your `ports:` block (e.g., `ports.redis` becomes `${PORT_REDIS}`). The validator rejects collisions at admin-add time.

### Shell-safety

Every substituted value is **shell-quoted** before landing in `.env` so passwords with `$`, quotes, or other special chars survive bash + Compose parsing intact. Author-declared static literals are the author's responsibility to quote.

Generated values from xCloud's generator are alphanumeric only — never special chars.

---

## Part 4: The Manifest

Drop a YAML manifest at `.xcloud/.xcloud-config.yaml`. Required keys: `schema_version`, `slug`, `name`, `description`, `version`, `app_version`, `icon`, `service_class`, `runtime`, `files`. Everything else is optional.

### Step 1 — Pick a service class

| Class | Domain? | SSL? | Auto-generated site name? | Examples |
|---|---|---|---|---|
| `web_app` | Yes | Yes | No (user picks the domain) | Ghost, Chatwoot, Grafana |
| `data_service` | No | No | Yes (`{slug}-{random6}`, e.g. `redis-a1b2c3`) | Redis, PostgreSQL, MongoDB |

The auto-generated name for `data_service` becomes the value of `${SITE_NAME}` and `${DOMAIN}` in your context. Use it in `container_name:` so multi-installs don't collide.

### Step 2 — Write the manifest

A minimal **Ghost** manifest (web_app, no lifecycle):

```yaml
# yaml-language-server: $schema=https://docs.xcloud.host/schemas/xcloud-template.v1.json
schema_version: 1

slug: ghost
name: Ghost
description: 'Open-source publishing platform for blogs, memberships, newsletters, and creator websites.'
version: '1.0.0'
app_version: '6'
icon: assets/icon.png
category: cms
service_class: web_app
runtime: docker_compose

tags: [cms, blog, publishing]

files:
  compose: docker-compose.yml
  env: .env

requirements:
  min_ram_mb: 1024
  min_cpu_cores: 1
  min_disk_gb: 4
  stack: [docker_nginx]

ports:
  main: { description: 'Ghost web interface', container_port: 2368, proxy: true }

generated_values:
  db_name:          { type: database_name, prefix: 'ghost_' }
  db_user:          { type: database_user, prefix: 'ghost_' }
  db_password:      { type: random, length: 24 }
  db_root_password: { type: random, length: 24 }

volumes:
  persistent: [ghost_content, ghost_db]

credentials:
  display:
    - { label: 'Site URL',          value: 'https://${DOMAIN}' }
    - { label: 'Admin URL',         value: 'https://${DOMAIN}/ghost/' }
    - { label: 'Database Name',     value: '${DB_NAME}' }
    - { label: 'Database User',     value: '${DB_USER}' }
    - { label: 'Database Password', value: '${DB_PASSWORD}', secret: true }

post_install:
  message: 'Ghost is running at https://${DOMAIN}. Finish setup from the admin panel at /ghost/.'
```

A **Chatwoot** manifest (web_app with lifecycle):

```yaml
schema_version: 1

slug: chatwoot
name: Chatwoot
description: 'Open-source customer engagement platform — chat, email, social inboxes, CRM.'
version: '1.0.0'
app_version: 'v3.16.0'
icon: assets/icon.png
category: communication
service_class: web_app
runtime: docker_compose

files:
  compose: docker-compose.yml
  env: .env

requirements:
  min_ram_mb: 4096
  min_cpu_cores: 2
  min_disk_gb: 20
  stack: [docker_nginx]

ports:
  rails: { description: 'Chatwoot HTTP', container_port: 3000, proxy: true }

fields:
  - { key: admin_email, label: 'Administrator email', type: email, required: true, group: admin }

field_groups:
  - { key: admin, label: 'Administrator', icon: 'user-circle' }

generated_values:
  secret_key_base:                              { type: random, length: 64 }
  active_record_encryption_primary_key:         { type: random, length: 32 }
  active_record_encryption_deterministic_key:   { type: random, length: 32 }
  active_record_encryption_key_derivation_salt: { type: random, length: 32 }
  postgres_password:                            { type: random, length: 32 }
  redis_password:                               { type: random, length: 24 }

volumes:
  persistent: [storage_data, postgres_data, redis_data]

credentials:
  display:
    - { label: URL, value: 'https://${DOMAIN}' }

lifecycle:
  post_install: { fetch: scripts/post-install.sh }

post_install:
  message: 'Chatwoot is ready at https://${DOMAIN}. The first signup becomes the admin account.'
```

### Step 3 — Manifest key reference

| Key | Required | What it does |
|---|---|---|
| `schema_version` | yes | Must be `1`. Any other value is rejected by `TemplateManifest`. |
| `slug` | yes | Lowercase alphanumeric + hyphens. Must be unique in the catalog. |
| `name`, `description`, `version` | yes | Display name, copy, manifest version. |
| `app_version` | yes | The app being installed (e.g. `'v3.16.0'`, `'29.0.4'`, `'latest'`). |
| `icon` | yes | Path to icon, **relative to `.xcloud/`** (e.g., `assets/icon.png` resolves to `.xcloud/assets/icon.png`). Allowed extensions: `png`, `jpg`, `jpeg`. SVG is rejected — same-origin SVGs can carry inline JS. |
| `category` | no | Free-form catalog tag. Default `general`. |
| `service_class` | yes | `web_app` or `data_service`. |
| `runtime` | yes | Must be `docker_compose` in v1. |
| `tags` | no | Array of strings for search/filter. |
| `files.compose` | yes (for docker_compose) | Path to compose file, relative to `.xcloud/`. |
| `files.env` | yes (for docker_compose) | Path to env file, relative to `.xcloud/`. |
| `requirements.{min_ram_mb, min_cpu_cores, min_disk_gb}` | no | Compared against the latest server-monitor snapshot. Templates with unmet requirements render as disabled cards in the catalog with a per-issue tooltip ("Requires 4 GB RAM, server has 2 GB."). Install endpoint also rejects mismatches. |
| `requirements.stack` | no | Allowed server stacks. Today only `[docker_nginx]`. |
| `ports` | yes (with at least one) | Map of port name → port object. See [Port object shape](#port-object-shape). |
| `fields` | no | User-input form fields. Cannot collide with reserved names. |
| `field_groups` | no | UI grouping for form fields. |
| `generated_values` | no | Server-generated secrets/identifiers. Cannot collide with reserved names. |
| `volumes.persistent` | no | Named docker volumes that survive across redeploys. |
| `credentials.display` | no | Array of `{label, value, secret?, type?}` rows shown on the credentials page. Every row gets a Copy button. Mark password rows with `secret: true` (or `type: password`) to render them masked with a show/hide toggle. If `display` is empty or unset, xCloud falls back to listing one row per port using `ports.<key>.description`. |
| `lifecycle.pre_install.fetch` | no | Path to a bash script (relative to `.xcloud/`) that runs before `docker compose up -d`. |
| `lifecycle.post_install.fetch` | no | Path to a bash script that runs after `docker compose up -d`. |
| `post_install.message` | no | Message shown above the credentials page after install. |

#### Port object shape

```yaml
ports:
  main:
    description: 'Ghost web interface'      # shown on credentials page when credentials.display is empty
    container_port: 2368                    # the port your container listens on
    proxy: true                             # true = public-facing (nginx vhost + SSL); false = exposed to host only (TCP)
```

Each port allocates a unique host port at install time. Reference it in `.env` as `PORT_<KEY>=${PORT_<KEY>}`, then `${PORT_<KEY>}` in compose.

Ports are TCP-only today. UDP support (and a meaningful `protocol:` field) is on the roadmap.

Templates with multiple `proxy: true` ports today only get a single public domain (the first proxied port). Multi-domain support is on the roadmap.

#### Field object shape

```yaml
fields:
  - key: admin_email                # → ${ADMIN_EMAIL} after declaring in .env
    label: 'Administrator email'
    type: email                     # text | email | password | number | select
    required: true
    placeholder: 'admin@example.com' # UI hint text only — not persisted
    default: 'postgres'             # install-time fallback if the user leaves the field empty
    validation: 'string|max:32'     # extra Laravel rules appended to required/nullable
    generate: true                  # password fields: auto-generate when empty
    generate_length: 24             # length of the generated value (default 16); alphanumeric only
    group: admin                    # references field_groups[].key
    help_text: 'Used for the admin login.'
    options:                        # required when type: select
      - { value: 'us', label: 'United States' }
      - { value: 'eu', label: 'Europe' }
```

**Supported types:** `text`, `email`, `password`, `number`, `select`. `url` and `textarea` are not rendered today — use `text` until those land.

**`placeholder` vs `default`:** `placeholder` is the gray hint text shown in the input; `default` is the value used at install if the user leaves the field blank. If you don't set `placeholder`, the form falls back to showing `default` as the hint.

**`generate: true`** only applies to `type: password` — leaving the field empty triggers `Str::random(generate_length || 16)` at install time. Generated values are stored on `oneclick_installations.generated_values` (encrypted) and re-rendered into `${KEY}` references in `.env`.

#### Generated value shape

```yaml
generated_values:
  db_password:
    type: random                    # random | database_name | database_user | uuid
    length: 24                      # for random (default 16); always alphanumeric
    prefix: 'app_'                  # for database_name / database_user
```

Generated values are referenced as `${DB_PASSWORD}` (uppercased, no prefix). Created once at install time, persisted on `oneclick_installations.generated_values` (encrypted), never regenerated.

#### What's inert (declared but not acted on yet)

- `singleton: true` — install-time uniqueness guard (planned)
- `install.directories: []` — pre-install directory creation (planned)
- `install.storage_check_gb: N` — pre-flight disk-space check (planned)
- `lifecycle.conditional_scripts[]` — conditional install variants based on form values (planned)
- `tags: []` — preserved on the manifest blob for a future catalog tag filter

Declare them today; they'll start working when those features ship without a schema change.

#### What was removed

These fields were parsed but never consumed — pruned in the v1 ship to avoid suggesting they do something:

- `ports.*.protocol` — TCP is implicit; UDP isn't supported end-to-end yet
- `ports.*.visibility` — advisory metadata; exposure is governed by `proxy:` and the firewall
- `credentials.type` — only `credentials.display[]` is read

---

## Part 5: The Compose File

`.xcloud/docker-compose.yml` is stored verbatim. Compose's native `${VAR}` interpolation reads from `/var/www/{site}/.env` at run time. **Every `${VAR}` you reference must be declared in your `.env`.**

A minimal Ghost compose:

```yaml
services:
  ghost:
    container_name: ghost-${SITE_NAME}
    image: ghost:${APP_VERSION}
    restart: always
    env_file: .env
    ports:
      - '127.0.0.1:${PORT_MAIN}:2368'
    volumes:
      - ghost_content:/var/lib/ghost/content
    networks:
      - xcloud-network
    depends_on:
      - db

  db:
    container_name: ghost-db-${SITE_NAME}
    image: mariadb:11
    restart: always
    environment:
      MARIADB_DATABASE: ${DB_NAME}
      MARIADB_USER: ${DB_USER}
      MARIADB_PASSWORD: ${DB_PASSWORD}
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
    volumes:
      - ghost_db:/var/lib/mysql
    networks:
      - xcloud-network

volumes:
  ghost_content:
  ghost_db:

networks:
  xcloud-network:
    driver: bridge
```

Pair with `.xcloud/.env`:

```env
SITE_NAME=${SITE_NAME}
APP_VERSION=6
PORT_MAIN=${PORT_MAIN}
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
```

**Conventions:**
- Bind proxied ports to `127.0.0.1` only — xCloud's nginx handles public exposure with SSL.
- Container names should include `${SITE_NAME}` so multiple installs on one server don't collide.
- Each install gets its own self-contained network (`driver: bridge`). Don't share networks across templates — installs must be independent.
- Use literal version numbers in `.env` (e.g., `APP_VERSION=6`) when you want a fixed pin, or `${APP_VERSION}` (mapped from manifest) when you want it manifest-driven.

---

## Part 6: The .env File

`.xcloud/.env` is the **single source of truth** for every variable your compose and lifecycle scripts use.

Two kinds of declarations:

```env
# Static literals — pass through verbatim
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
DEFAULT_LOCALE=en

# Context references — xCloud expands at install time and shell-quotes the result
DOMAIN=${DOMAIN}
SITE_NAME=${SITE_NAME}
PORT_RAILS=${PORT_RAILS}
SECRET_KEY_BASE=${SECRET_KEY_BASE}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
ADMIN_EMAIL=${ADMIN_EMAIL}
```

Compose reads the resulting file and interpolates `${VAR}` into `compose.yml`. Lifecycle scripts source it and use `$VAR` natively.

> **Note on Compose's `.env` parser:** Docker Compose treats `.env` values as *literals* — it does NOT expand `${VAR}` references inside `.env` at run time. xCloud's render step expands them at install time so the file Compose reads has only literal values. For values that need to be derived from context using bash logic (e.g., concatenations), put them in compose's `environment:` block where Compose's interpolation works natively.

> **Avoid empty SMTP placeholders.** Some apps (Vaultwarden, Chatwoot) crash-loop when `SMTP_*` keys are present but empty. If your app validates partial SMTP config, leave SMTP entirely out of `.env` and document the post-install block in your README instead of shipping empty placeholders.

---

## Part 7: Lifecycle Scripts (optional)

Used for apps that need a one-shot bootstrap step beyond `docker compose up -d` — Chatwoot's `rails db:chatwoot_prepare`, Mautic's setup wizard handoff, Bookstack's `php artisan migrate`, etc.

Two slots, both optional:

- **`lifecycle.pre_install.fetch`** — runs *before* `docker compose up -d`. Useful for "wait for X to be ready", filesystem prep.
- **`lifecycle.post_install.fetch`** — runs *after* `docker compose up -d`. Useful for migrations, admin user creation, smoke checks.

xCloud automatically wraps your bash with a sourcing prelude:

```bash
set -a
source /var/www/{site}/.env
set +a

# your bash here, with $VAR available natively
```

So you write plain bash:

```bash
#!/usr/bin/env bash
# .xcloud/scripts/post-install.sh
set -euo pipefail

cd "/var/www/$SITE_NAME"

echo "[chatwoot] waiting for postgres..."
attempts=0
until docker compose exec -T postgres pg_isready -U postgres -d chatwoot >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
        echo "[chatwoot] postgres did not become ready within 60s"
        exit 1
    fi
    sleep 2
done

echo "[chatwoot] running db:chatwoot_prepare..."
docker compose run --rm rails bundle exec rails db:chatwoot_prepare
```

Lifecycle bash is **re-fetched from GitHub at the pinned SHA** inside the install Job — no rendered output is persisted in the DB.

### Failure semantics

- **Pre fails** (non-zero exit) → install marked `pre_install_failed`, main install never runs.
- **Main fails** → existing behavior. Post never runs.
- **Post fails** → install marked `post_install_failed`, **compose is left running** so the admin can SSH in, inspect logs, or re-trigger the script. xCloud does not auto-rollback because most post failures are transient and the bash is typically idempotent.

### Timeouts

Hardcoded for v1: pre 300s, post 600s.

### What you can't do (yet)

- **Conditional scripts** — declared via `lifecycle.conditional_scripts[]` but not executed yet.
- **Run as a non-root user** — every script runs as the SSH user (root). Use `sudo -u $SITE_USER` inside your bash if you need site-user privileges.
- **Stream stdout to the UI** — bash output is captured on the Task row, not streamed live.

---

## Part 8: Smoke-test locally

Drop a real `.env` next to your compose with the values xCloud would fill in, then `docker compose up -d` from `.xcloud/`. The compose file is standard — no xCloud-specific syntax to substitute.

```bash
cd your-template/.xcloud
cp .env .env.local

# Fill .env.local with real values:
# SITE_NAME=test-install
# DOMAIN=test.local
# DB_PASSWORD=somerandompassword
# ...

docker compose --env-file .env.local up -d
curl http://localhost:8080
```

---

## Part 9: Drop the icon

Save the icon under `.xcloud/` at the path your `manifest.icon` points to. Recommended: `.xcloud/assets/icon.png` (manifest declares `icon: assets/icon.png`), 256×256 or larger.

**Allowed extensions:** `png`, `jpg`, `jpeg`. SVG is rejected because same-origin SVGs can carry inline JS that executes when the icon URL is loaded directly. Anything else is rejected at admin-add / re-sync time and the catalog row is left unchanged.

xCloud fetches the icon at admin-add and re-sync time, persists it to `public/img/oneclick/{slug}.{ext}` on the xCloud host, and stamps the path on `oneclick_templates.local_icon_path`. Old files are GC'd if you change the extension on a re-sync, and on template delete.

---

## Part 10: Health — what the dashboard shows

After install, xCloud's site-overview page displays:

- **Container status** — running / exited / unhealthy / restarting per container, refreshed from the latest server-monitor snapshot (~5 minutes).
- **Last-checked timestamp** — when the monitor last polled.
- **Credentials card** — every row from `credentials.display[]` with a Copy button; password rows masked with show/hide toggle.
- **Post-install message** — `post_install.message` rendered above the credentials card.

You don't write any of this — it's automatic from the manifest and the server monitor.

---

## Part 11: Registering the Template (Admin Nova Page)

Once your template folder is on `main` with a valid `.xcloud/.xcloud-config.yaml`, an xCloud admin:

1. Navigates to **Nova → OneClick Templates**.
2. Clicks **Add Template From GitHub**, pastes the template folder URL.
3. xCloud resolves the latest commit that touched your `{slug}/` folder (path-scoped SHA), fetches `.xcloud/.xcloud-config.yaml`, validates via `TemplateManifest`, fetches and persists the icon, inserts a draft row with `is_active = false`.
4. The admin runs the **Edit Flags** action to flip `is_active = true`. The template appears in the public catalog.

### Catalog visibility flags

The Edit Flags action exposes two booleans on every row, both default `false`:

| Flag | Effect |
|---|---|
| `is_active` | Master switch — the template only appears in the public catalog (and is installable) when `true`. |
| `is_for_admin` | Limits visibility to admin / superadmin users. Non-admins don't see the row at all and the install endpoint 404s for them. Use for internal tooling templates. |

A separate flag, `is_beta`, lives directly on the row (no UI yet — set via DB or Nova console if needed). Beta templates show in the catalog but the install endpoint returns 403 unless the installing **team** has the slug in their `beta_features` meta. Use this for staged rollouts.

### Re-sync semantics

When you ship a change, the admin clicks **Re-sync Template**. xCloud re-resolves the latest commit that touched your `{slug}/` folder (path-scoped SHA), re-fetches the manifest, re-validates, and re-fetches the icon (deleting the old file if the extension changed). **Existing customer installs are not affected** — they stay pinned to the SHA from when they were installed. Only new installs use the updated content. Editing one template never moves another template's pin.

If your re-synced manifest fails validation, the catalog row is **left unchanged** and the error is surfaced to the admin. A bad push never breaks a working template.

### Delete

The Delete action is blocked when any installations exist for the template. To remove a template with live sites, the admin has to delete those sites first. On delete, the local icon file is also removed.

---

## Part 12: Building Your Own Image

If your app doesn't have a published Docker image:

1. Write a `Dockerfile` in your application repo (NOT this template repo).
2. Push the image to Docker Hub, GitHub Container Registry (`ghcr.io`), or any public registry.
3. Reference that image in your template's `docker-compose.yml`:
   ```yaml
   image: ghcr.io/yourorg/yourapp:${APP_VERSION}
   ```
4. Set `APP_VERSION=...` in your `.env` and bump it when you publish a new image tag.

---

## Part 13: Troubleshooting

**"Manifest is missing required key `X`"** — check `schema_version`, `slug`, `name`, `description`, `version`, `app_version`, `icon`, `service_class`, `runtime`, `files.compose`, `files.env`.

**"runtime `X` not supported in Phase A"** — only `docker_compose` is supported in v1.

**"fields[].key `X` collides with reserved env var"** — your field/generated_value/port key collides with `SITE_NAME`/`SITE_USER`/`DOMAIN`/`SERVER_IP`. Rename your key.

**"Could not fetch URL (HTTP 404)"** — your repo or one of the declared files isn't reachable. Verify the repo is **public**, file paths are relative to `.xcloud/`, and the files exist on `main`.

**"runtime: docker_compose requires files.compose and files.env"** — both keys must be set, even if your env template is empty.

**`${VAR}` not expanding in compose** — verify the key is declared in `.env`. Compose only interpolates from `.env`.

**`${VAR}` showing as literal in `.env` after install** — the key didn't exist in xCloud's context. Common cause: typo (`${ADMIN_PASS}` vs `${ADMIN_PASSWORD}`) or referencing a context var that doesn't exist (`${RESOURCES_X}` is not a context key today). The validator catches undefined references at install time.

**`post_install_failed` status** — the post-install script exited non-zero. Compose is still running. Click the failed Task in Nova for the bash output. Fix in your repo, push, and Re-sync; new installs use the fixed script.

**Credentials page is blank** — you forgot `credentials.display[]`. Without it, xCloud falls back to listing every form field.

---

## Validation Checklist

Before opening a PR (or asking an admin to add your template):

- [ ] `.xcloud/.xcloud-config.yaml` exists and parses cleanly (`yamllint .xcloud/.xcloud-config.yaml`)
- [ ] `schema_version: 1` set
- [ ] `slug` lowercase alphanumeric + hyphens, unique
- [ ] `service_class` is `web_app` or `data_service`
- [ ] `runtime: docker_compose`
- [ ] `files.compose` and `files.env` point at files that exist under `.xcloud/`
- [ ] No `fields[].key` / `generated_values.<key>` / `ports.<key>` collides with `site_name`, `site_user`, `domain`, or `server_ip` (case-insensitive)
- [ ] No `fields[].key` / `generated_values.<key>` starts with `port_` (the `PORT_*` namespace is auto-injected from your `ports:` block)
- [ ] At least one `ports` entry, with `proxy: true` for the public-facing port (web apps only)
- [ ] `requirements.stack: [docker_nginx]` set
- [ ] `.env` declares every `${VAR}` that compose or lifecycle scripts reference
- [ ] Compose binds proxied ports to `127.0.0.1` and uses a self-contained `xcloud-network` (`driver: bridge`)
- [ ] Container names include `${SITE_NAME}`
- [ ] `app_version` pinned to a real image tag
- [ ] Locally smoke-tested with `docker compose --env-file .env.local up -d`
- [ ] If lifecycle scripts are declared: each is `chmod +x` and exits cleanly on success
- [ ] Icon file exists under `.xcloud/` at the path declared in `manifest.icon` (e.g. `.xcloud/assets/icon.png` for `icon: assets/icon.png`); extension is one of png/jpg/jpeg
- [ ] `credentials.display[]` lists every value the user needs
- [ ] `post_install.message` set with at least the URL or connection hint
- [ ] Per-template `README.md` documents fields, generated values, first-run, and volume backup
