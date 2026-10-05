-- USERS: both customers and providers
CREATE TABLE IF NOT EXISTS users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(255) NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role          VARCHAR(20) NOT NULL CHECK (role IN ('customer', 'provider')),
  phone         VARCHAR(20),
  fcm_token     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- SERVICES: what a provider offers (haircut, consultation, tuition)
CREATE TABLE IF NOT EXISTS services (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title            VARCHAR(150) NOT NULL,
  description      TEXT,
  category         VARCHAR(50),
  price_paise      INTEGER NOT NULL CHECK (price_paise >= 0),
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  is_active        BOOLEAN NOT NULL DEFAULT true,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- SLOTS: available time windows for a service
CREATE TABLE IF NOT EXISTS slots (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
  start_time TIMESTAMPTZ NOT NULL,
  end_time   TIMESTAMPTZ NOT NULL,
  CHECK (end_time > start_time),
  UNIQUE (service_id, start_time)
);

-- BOOKINGS: a customer reserving a slot
CREATE TABLE IF NOT EXISTS bookings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id     UUID NOT NULL REFERENCES slots(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status      VARCHAR(20) NOT NULL DEFAULT 'pending'
              CHECK (status IN ('pending', 'confirmed', 'cancelled', 'completed')),
  expires_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- THE KEY RULE: only one active booking per slot (prevents double booking)
CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_booking_per_slot
  ON bookings (slot_id)
  WHERE status IN ('pending', 'confirmed');

-- PAYMENTS: Razorpay records
CREATE TABLE IF NOT EXISTS payments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id          UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  razorpay_order_id   VARCHAR(100) NOT NULL UNIQUE,
  razorpay_payment_id VARCHAR(100),
  amount_paise        INTEGER NOT NULL,
  status              VARCHAR(20) NOT NULL DEFAULT 'created'
                      CHECK (status IN ('created', 'paid', 'failed', 'refunded')),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- REVIEWS: one review per booking
CREATE TABLE IF NOT EXISTS reviews (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
  rating     INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- INDEXES for the queries we'll run most
CREATE INDEX IF NOT EXISTS idx_services_provider ON services (provider_id);
CREATE INDEX IF NOT EXISTS idx_services_category ON services (category) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_slots_service_start ON slots (service_id, start_time);
CREATE INDEX IF NOT EXISTS idx_bookings_customer ON bookings (customer_id);