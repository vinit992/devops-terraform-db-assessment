#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
file="${1:-$(find backups -maxdepth 1 -name 'hotels_*.dump' -type f 2>/dev/null | sort | tail -n 1)}"
if [[ -z "$file" || ! -s "$file" ]]; then echo "Backup missing. Run ./scripts/backup.sh first." >&2; exit 1; fi
docker compose --profile restore up -d --wait restore_db
# Fresh database every time; schema and data come from the dump, not init scripts.
docker compose exec -T restore_db psql -U hotel -d postgres -v ON_ERROR_STOP=1 -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='hotels_restore' AND pid <> pg_backend_pid();" >/dev/null
docker compose exec -T restore_db dropdb -U hotel --if-exists hotels_restore
docker compose exec -T restore_db createdb -U hotel hotels_restore
docker compose exec -T restore_db pg_restore -U hotel -d hotels_restore --no-owner --no-acl --exit-on-error < "$file"
echo "Restored $file into fresh hotels_restore database"
