CREATE TABLE hotel_bookings (
  id UUID PRIMARY KEY,
  org_id UUID NOT NULL,
  hotel_id VARCHAR(100) NOT NULL,
  city VARCHAR(100) NOT NULL,
  checkin_date DATE NOT NULL,
  checkout_date DATE NOT NULL,
  amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
  status VARCHAR(50) NOT NULL,
  created_at TIMESTAMP NOT NULL,
  CONSTRAINT valid_stay CHECK (checkout_date > checkin_date)
);
CREATE TABLE booking_events (
  id BIGSERIAL PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES hotel_bookings(id),
  event_type VARCHAR(100) NOT NULL,
  payload JSONB,
  created_at TIMESTAMP NOT NULL
);
CREATE INDEX idx_bookings_city_created_org_status
  ON hotel_bookings (city, created_at DESC, org_id, status) INCLUDE (amount);
CREATE INDEX idx_booking_events_booking_id ON booking_events (booking_id);
