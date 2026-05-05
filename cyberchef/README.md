# CyberChef — xCloud OneClick template

The Cyber Swiss Army Knife. Web-based tool for encryption, encoding, compression, and data analysis. Originally built by GCHQ; now a community-maintained open-source project. Single static SPA — runs entirely in the browser, the server just serves files.

## What this template ships

- **Image:** `ghcr.io/gchq/cyberchef:11.0.0` (pinned) — based on `nginxinc/nginx-unprivileged:stable-alpine`
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `8080` proxied as `main` (the unprivileged nginx variant binds 8080 since it doesn't run as root)
- **Volume:** none — fully stateless
- **Database:** none

## Fields the install form asks for

None.

## Auto-generated values

None.

## What the user gets in the credentials panel

- **URL** — `https://${DOMAIN}`

## First-run

Open `https://${DOMAIN}`. That's it. No account, no setup, no admin panel.

CyberChef's UI:
- **Operations panel (left)** — drag operations from here onto the recipe.
- **Recipe (middle)** — the chain of operations. Each output feeds the next.
- **Input/Output (right)** — paste your data, see the result update live.

Everything runs in the browser — none of your input is sent to the server. The server's only job is delivering the static SPA on first load.

## Common use cases

- Decode JWT tokens, extract claims
- Convert between hex/base64/URL/HTML encoding
- Hash/HMAC with SHA-256, MD5, etc.
- Decrypt AES/DES with a known key
- Parse User-Agent strings, IP addresses, timestamps
- Inspect protocol buffers, decode CBOR
- Format JSON, XML, YAML
- Convert character encodings (UTF-8 ↔ Latin-1, etc.)

## Hardening

There are no built-in accounts or auth. Anyone who can reach the URL can use the tool. To restrict access:

- **Basic Authentication** — open this site → Settings → Basic Authentication → enable, set a username/password.
- **IP Allowlist** — Tools → IP Management → restrict to office/VPN IPs.
- **Run on internal network only** — set the site's nginx listen address to a private interface, or skip the public domain entirely (advanced).

## Re-sync / upgrade

The pinned `11.0.0` tag is immutable. To upgrade: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.**

## Volume backup

Nothing to back up — the entire app is contained in the image.

## Why this template is the simplest in the catalog

CyberChef is a static SPA. The container has:
- No environment variables to configure
- No database, no SQLite file
- No persistent volume
- No admin user
- No first-run wizard
- No SMTP / OAuth / SSO

It cannot fail in the way most other templates can. The only failure modes are network (image pull) or bad image tag — both caught at install time.
