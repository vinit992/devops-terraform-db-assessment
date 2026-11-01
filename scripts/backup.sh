#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
file="backups/hotels_${stamp}.dump"
docker compose exec -T db pg_dump -U hotel -d hotels -Fc --no-owner --no-acl > "$file"
test -s "$file"
echo "Backup created: $file"
