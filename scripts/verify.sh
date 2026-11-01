#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
q="SELECT (SELECT COUNT(*) FROM hotel_bookings)::text || ':' || (SELECT COUNT(*) FROM booking_events)::text || ':' || (SELECT COALESCE(SUM(amount),0) FROM hotel_bookings)::text;"
source_counts="$(docker compose exec -T db psql -U hotel -d hotels -At -c "$q")"
restore_counts="$(docker compose exec -T restore_db psql -U hotel -d hotels_restore -At -c "$q")"
echo "Original: $source_counts"
echo "Restored: $restore_counts"
test "$source_counts" = "$restore_counts"
test "${source_counts%%:*}" -ge 100
echo "PASS: counts and total amount match"
