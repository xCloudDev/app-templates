#!/usr/bin/env bash
# Chatwoot post-install — runs after `docker compose up -d` succeeds.
#
# Chatwoot's `db:chatwoot_prepare` is an idempotent Rake task that:
#   • db:setup if no DB exists
#   • loads schema + db:seed if the DB is fresh (no ar_internal_metadata)
#   • db:migrate if the DB is established
#
# Without it, the Rails app errors on first request — there are no tables.
# After it, a fresh install is ready and a re-run is a safe no-op (just
# applies any pending migrations).
set -euo pipefail

cd "/var/www/${SITE_NAME}"

echo "[chatwoot] waiting for postgres to accept connections..."
attempts=0
until docker compose exec -T postgres pg_isready -U postgres -d chatwoot >/dev/null 2>&1; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 30 ]; then
        echo "[chatwoot] postgres did not become ready within 60s"
        exit 1
    fi
    sleep 2
done

echo "[chatwoot] running db:chatwoot_prepare (migrations + seed)..."
docker compose run --rm rails bundle exec rails db:chatwoot_prepare

echo "[chatwoot] post-install complete — visit https://${DOMAIN} to create your admin account."
