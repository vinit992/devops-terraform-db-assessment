INSERT INTO hotel_bookings (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT
  ('00000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
  ('10000000-0000-4000-8000-' || lpad(((g % 5) + 1)::text, 12, '0'))::uuid,
  'hotel-' || ((g % 12) + 1),
  (ARRAY['delhi', 'mumbai', 'bengaluru', 'chennai', 'hyderabad'])[1 + (g % 5)],
  CURRENT_DATE + (g % 60),
  CURRENT_DATE + (g % 60) + 2,
  (1500 + (g % 20) * 250)::numeric(12,2),
  (ARRAY['confirmed', 'cancelled', 'pending'])[1 + (g % 3)],
  LOCALTIMESTAMP - (g % 45) * INTERVAL '1 day'
FROM generate_series(1, 250) AS g;
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'created', jsonb_build_object('source', 'seed'), created_at
FROM hotel_bookings WHERE right(id::text, 2)::int % 2 = 0;
