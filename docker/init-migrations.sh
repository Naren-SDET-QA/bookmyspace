#!/usr/bin/env bash
# Applies all Supabase migrations in order on first container boot.
# Runs inside the postgres container via the docker-entrypoint-initdb.d hook.
set -euo pipefail

echo "==> Applying auth stub"
psql -U postgres -d bookmyspace -v ON_ERROR_STOP=1 -f /docker-entrypoint-initdb.d/000-stub.sql

echo "==> Applying migrations"
for f in /migrations/*.sql; do
  echo "==> $f"
  psql -U postgres -d bookmyspace -v ON_ERROR_STOP=1 -f "$f"
done

echo "==> Migrations complete"
