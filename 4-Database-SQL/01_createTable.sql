-- PostgreSQL - iPhone Fiyat Tahmin Sistemi
-- 01) CREATE TABLE

-- 1) USERS
CREATE TABLE users (
  user_id        bigserial PRIMARY KEY,
  username       varchar(50)  NOT NULL UNIQUE,
  password_hash  varchar(255) NOT NULL,
  user_email     varchar(255) UNIQUE,
  created_at     timestamptz  NOT NULL DEFAULT now(),
  CHECK (user_email IS NULL OR position('@' in user_email) > 1)
);

-- 2) ROLES
CREATE TABLE roles (
  role_id   smallserial PRIMARY KEY,
  role_name varchar(50) NOT NULL UNIQUE
);

-- 3) USER_ROLE (N:N)
CREATE TABLE user_role (
  user_id bigint   NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  role_id smallint NOT NULL REFERENCES roles(role_id) ON DELETE RESTRICT,
  PRIMARY KEY (user_id, role_id)
);

-- 4) MODEL_SEGMENTS (Pro, Pro Max, Mini, Base, Plus...)
CREATE TABLE model_segments (
  segment_id   smallserial PRIMARY KEY,
  segment_name varchar(30) NOT NULL UNIQUE
    CHECK (segment_name IN ('Base','Mini','Plus','Pro','Pro Max'))
);

-- 5) MODELS (Model adı + segment FK)
-- Örn: model_name='iPhone 11', segment='Pro'
CREATE TABLE models (
  model_id      bigserial PRIMARY KEY,
  model_name    varchar(100) NOT NULL,
  segment_id    smallint NOT NULL REFERENCES model_segments(segment_id) ON DELETE RESTRICT,
  release_year  integer NOT NULL CHECK (release_year BETWEEN 2007 AND 2100),
  UNIQUE (model_name, segment_id, release_year)
);

-- 6) SPECS (Donanım özellik kombinasyonları)
CREATE TABLE specs (
  specs_id      bigserial PRIMARY KEY,
  model_id      bigint NOT NULL REFERENCES models(model_id) ON DELETE CASCADE,

  ram_gb        integer NOT NULL CHECK (ram_gb BETWEEN 1 AND 32),
  kamera_mp     integer NOT NULL CHECK (kamera_mp BETWEEN 1 AND 200),
  ekran_boyutu  numeric(3,1) NOT NULL CHECK (ekran_boyutu BETWEEN 3.0 AND 8.0),
  batarya_mah   integer NOT NULL CHECK (batarya_mah BETWEEN 500 AND 10000),
  hafiza_gb     integer NOT NULL CHECK (hafiza_gb BETWEEN 8 AND 2048),

  UNIQUE (model_id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb)
);

-- 7) DEVICE_CONDITION (Durum sözlüğü)
CREATE TABLE device_condition (
  condition_id   smallserial PRIMARY KEY,
  condition_name varchar(30) NOT NULL UNIQUE
    CHECK (condition_name IN ('Mükemmel','Çok İyi','İyi','Orta','Kötü'))
);

-- 8) PREDICTIONS (Tahmin kayıtları)
CREATE TABLE predictions (
  prediction_id     bigserial PRIMARY KEY,

  specs_id          bigint NOT NULL REFERENCES specs(specs_id) ON DELETE RESTRICT,
  user_id           bigint REFERENCES users(user_id) ON DELETE SET NULL,
  condition_id      smallint NOT NULL REFERENCES device_condition(condition_id) ON DELETE RESTRICT,

  predicted_price   numeric(12,2) NOT NULL CHECK (predicted_price > 0),
  confidence_score  numeric(5,2) CHECK (confidence_score IS NULL OR (confidence_score BETWEEN 0 AND 100)),
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- Performans indeksleri (önerilir)
CREATE INDEX idx_specs_model_id             ON specs(model_id);
CREATE INDEX idx_predictions_user_time      ON predictions(user_id, created_at DESC);
CREATE INDEX idx_predictions_specs_id       ON predictions(specs_id);
CREATE INDEX idx_models_segment_id          ON models(segment_id);

-- EF Core için System Logs tablosu
CREATE TABLE IF NOT EXISTS system_logs (
    log_id SERIAL PRIMARY KEY,
    user_id BIGINT,
    username VARCHAR(100),
    action VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);