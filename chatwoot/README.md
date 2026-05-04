# Chatwoot — xCloud OneClick template

Open-source customer engagement platform: chat, email, social inboxes, CRM. Multi-service stack — Rails + Sidekiq + Postgres (pgvector) + Redis.

## What this template ships

- **Image:** `chatwoot/chatwoot:v3.16.0` (pinned, used for both `rails` and `sidekiq` services)
- **Sidecars:** `pgvector/pgvector:pg16` (Postgres + pgvector), `redis:7-alpine`
- **Service class:** `web_app` — domain + HTTPS via xCloud's nginx
- **Port:** container `3000` (Rails) proxied as `rails`; Postgres/Redis exposed only on the internal compose network
- **Volumes:** `storage_data:/app/storage` (uploads, ActiveStorage), `postgres_data:/var/lib/postgresql/data`, `redis_data:/data`

## Fields the install form asks for

None.

## Auto-generated values

| Key | Used as | Format |
|---|---|---|
| `secret_key_base` | `SECRET_KEY_BASE` | 64 chars random |
| `active_record_encryption_primary_key` | `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | 32 chars random |
| `active_record_encryption_deterministic_key` | `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | 32 chars random |
| `active_record_encryption_key_derivation_salt` | `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | 32 chars random |
| `postgres_password` | `POSTGRES_PASSWORD` | 32 chars random |
| `redis_password` | `REDIS_PASSWORD` | 24 chars random |

## What the user gets in the credentials panel

- **URL** — `https://${DOMAIN}`

## First-run

1. Visit `https://${DOMAIN}`. The first signup becomes the admin account.
2. After creating the admin, lock further registrations:
   ```bash
   ssh into the server
   cd /var/www/${SITE_NAME}
   sed -i 's/ENABLE_ACCOUNT_SIGNUP=true/ENABLE_ACCOUNT_SIGNUP=false/' .env
   docker compose up -d
   ```

The post-install lifecycle script runs `bundle exec rails db:chatwoot_prepare` once Postgres is reachable — applies schema, seeds, and any pending migrations. Idempotent on re-run.

## SMTP (optional)

Pre-declared as empty placeholders in `.env`. Required for invitations, password reset, and conversation notifications. Edit the rendered `.env` post-install and `docker compose up -d` to apply:

```
MAILER_SENDER_EMAIL=noreply@example.com
SMTP_DOMAIN=example.com
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=...
SMTP_PASSWORD=...
SMTP_AUTHENTICATION=login
SMTP_ENABLE_STARTTLS_AUTO=true
```

## Storage (optional)

`ACTIVE_STORAGE_SERVICE=local` by default — uploads land on the `storage_data` volume. To move to S3, edit `.env` post-install with the Chatwoot ActiveStorage S3 keys and restart.

## Re-sync / upgrade

The pinned `v3.16.0` tag is immutable. To upgrade: bump `app_version` in the manifest, re-sync the template in Nova, the next install pulls the new image. **Existing installs stay on their pinned SHA.** Major-version upgrades may require running the post-install script again — check Chatwoot release notes.

## Volume backup

Back up all three Docker volumes to capture full state:
- `<site-name>_storage_data` — uploads, attachments
- `<site-name>_postgres_data` — conversations, contacts, accounts
- `<site-name>_redis_data` — Sidekiq queues, cache

The encryption keys are xCloud-managed and persist in `oneclick_installations.generated_values`, so a full volume restore on a new install is decryptable as long as the original install record exists.
