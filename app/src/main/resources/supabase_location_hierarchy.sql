-- ==============================================================================
-- BookMySpace: Complete India Location Hierarchy Master Data & RLS Migration
-- Supports: Country -> State -> District -> Mandal -> City/Town/Village -> Area
-- Scalable for Andhra Pradesh, Telangana, Karnataka, Tamil Nadu, Maharashtra, etc.
-- ==============================================================================

-- 1. Countries Master Table
CREATE TABLE IF NOT EXISTS location_countries (
    id VARCHAR(10) PRIMARY KEY, -- e.g. 'IN'
    code VARCHAR(10) NOT NULL UNIQUE, -- 'IND'
    name VARCHAR(100) NOT NULL,
    phone_code VARCHAR(10) DEFAULT '+91',
    currency VARCHAR(10) DEFAULT 'INR',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. States Master Table
CREATE TABLE IF NOT EXISTS location_states (
    id VARCHAR(20) PRIMARY KEY, -- e.g. 'IN-AP', 'IN-TG'
    country_id VARCHAR(10) NOT NULL REFERENCES location_countries(id) ON DELETE RESTRICT,
    code VARCHAR(10) NOT NULL, -- 'AP', 'TG'
    name VARCHAR(100) NOT NULL,
    capital_city VARCHAR(100),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    display_order INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(country_id, code)
);

CREATE INDEX IF NOT EXISTS idx_states_country ON location_states(country_id);
CREATE INDEX IF NOT EXISTS idx_states_name ON location_states(name);

-- 3. Districts Master Table
CREATE TABLE IF NOT EXISTS location_districts (
    id VARCHAR(50) PRIMARY KEY, -- e.g. 'DIST_AP_PRAKASAM', 'DIST_TG_HYDERABAD'
    state_id VARCHAR(20) NOT NULL REFERENCES location_states(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(20),
    headquarters VARCHAR(100),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(state_id, name)
);

CREATE INDEX IF NOT EXISTS idx_districts_state ON location_districts(state_id);
CREATE INDEX IF NOT EXISTS idx_districts_name ON location_districts(name);

-- 4. Mandals / Taluks / Tehsils Master Table
CREATE TABLE IF NOT EXISTS location_mandals (
    id VARCHAR(60) PRIMARY KEY, -- e.g. 'MANDAL_AP_ONGOLE', 'MANDAL_TG_SERILINGAMPALLY'
    district_id VARCHAR(50) NOT NULL REFERENCES location_districts(id) ON DELETE RESTRICT,
    state_id VARCHAR(20) NOT NULL REFERENCES location_states(id) ON DELETE RESTRICT,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(30),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mandals_district ON location_mandals(district_id);
CREATE INDEX IF NOT EXISTS idx_mandals_state ON location_mandals(state_id);
CREATE INDEX IF NOT EXISTS idx_mandals_name ON location_mandals(name);

-- 5. Cities / Towns / Villages Master Table
CREATE TABLE IF NOT EXISTS location_cities_towns (
    id VARCHAR(70) PRIMARY KEY, -- e.g. 'CITY_AP_ONGOLE', 'CITY_TG_HYDERABAD'
    mandal_id VARCHAR(60) REFERENCES location_mandals(id) ON DELETE SET NULL,
    district_id VARCHAR(50) NOT NULL REFERENCES location_districts(id) ON DELETE RESTRICT,
    state_id VARCHAR(20) NOT NULL REFERENCES location_states(id) ON DELETE RESTRICT,
    name VARCHAR(120) NOT NULL,
    type VARCHAR(30) DEFAULT 'CITY', -- METRO_CITY, CITY, TOWN, VILLAGE
    postal_code VARCHAR(10),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cities_mandal ON location_cities_towns(mandal_id);
CREATE INDEX IF NOT EXISTS idx_cities_district ON location_cities_towns(district_id);
CREATE INDEX IF NOT EXISTS idx_cities_state ON location_cities_towns(state_id);
CREATE INDEX IF NOT EXISTS idx_cities_name ON location_cities_towns(name);

-- 6. Areas / Localities / Neighborhoods Master Table
CREATE TABLE IF NOT EXISTS location_areas (
    id VARCHAR(80) PRIMARY KEY, -- e.g. 'AREA_AP_ONG_LAWYERPET', 'AREA_TG_HYD_GACHIBOWLI'
    city_town_id VARCHAR(70) NOT NULL REFERENCES location_cities_towns(id) ON DELETE RESTRICT,
    mandal_id VARCHAR(60) REFERENCES location_mandals(id) ON DELETE SET NULL,
    district_id VARCHAR(50) NOT NULL REFERENCES location_districts(id) ON DELETE RESTRICT,
    state_id VARCHAR(20) NOT NULL REFERENCES location_states(id) ON DELETE RESTRICT,
    name VARCHAR(150) NOT NULL,
    postal_code VARCHAR(10),
    landmark TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    is_popular BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_areas_city ON location_areas(city_town_id);
CREATE INDEX IF NOT EXISTS idx_areas_mandal ON location_areas(mandal_id);
CREATE INDEX IF NOT EXISTS idx_areas_district ON location_areas(district_id);
CREATE INDEX IF NOT EXISTS idx_areas_postal ON location_areas(postal_code);
CREATE INDEX IF NOT EXISTS idx_areas_popular ON location_areas(is_popular);

-- ==============================================================================
-- 7. Add Relational Location Columns to Listings Table
-- ==============================================================================

ALTER TABLE IF EXISTS venues
    ADD COLUMN IF NOT EXISTS state_id VARCHAR(20) REFERENCES location_states(id),
    ADD COLUMN IF NOT EXISTS district_id VARCHAR(50) REFERENCES location_districts(id),
    ADD COLUMN IF NOT EXISTS mandal_id VARCHAR(60) REFERENCES location_mandals(id),
    ADD COLUMN IF NOT EXISTS city_town_id VARCHAR(70) REFERENCES location_cities_towns(id),
    ADD COLUMN IF NOT EXISTS area_id VARCHAR(80) REFERENCES location_areas(id);

CREATE INDEX IF NOT EXISTS idx_venues_state_id ON venues(state_id);
CREATE INDEX IF NOT EXISTS idx_venues_district_id ON venues(district_id);
CREATE INDEX IF NOT EXISTS idx_venues_mandal_id ON venues(mandal_id);
CREATE INDEX IF NOT EXISTS idx_venues_city_town_id ON venues(city_town_id);
CREATE INDEX IF NOT EXISTS idx_venues_area_id ON venues(area_id);

-- ==============================================================================
-- 8. Row Level Security (RLS) Policies for Scalability and Integrity
-- ==============================================================================

ALTER TABLE location_countries ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_districts ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_mandals ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_cities_towns ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_areas ENABLE ROW LEVEL SECURITY;

-- Read Access: Allow public and authenticated users to read location master data
CREATE POLICY "Public Read Countries" ON location_countries FOR SELECT USING (true);
CREATE POLICY "Public Read States" ON location_states FOR SELECT USING (true);
CREATE POLICY "Public Read Districts" ON location_districts FOR SELECT USING (true);
CREATE POLICY "Public Read Mandals" ON location_mandals FOR SELECT USING (true);
CREATE POLICY "Public Read Cities" ON location_cities_towns FOR SELECT USING (true);
CREATE POLICY "Public Read Areas" ON location_areas FOR SELECT USING (true);

-- Write Access: Only admins can mutate location master tables
CREATE POLICY "Admin All Countries" ON location_countries FOR ALL USING (
    auth.uid() IN (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'ADMIN')
);
CREATE POLICY "Admin All States" ON location_states FOR ALL USING (
    auth.uid() IN (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'ADMIN')
);
CREATE POLICY "Admin All Districts" ON location_districts FOR ALL USING (
    auth.uid() IN (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'ADMIN')
);
CREATE POLICY "Admin All Mandals" ON location_mandals FOR ALL USING (
    auth.uid() IN (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'ADMIN')
);
CREATE POLICY "Admin All Cities" ON location_cities_towns FOR ALL USING (
    auth.uid() IN (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'ADMIN')
);
CREATE POLICY "Admin All Areas" ON location_areas FOR ALL USING (
    auth.uid() IN (SELECT id FROM auth.users WHERE raw_user_meta_data->>'role' = 'ADMIN')
);
