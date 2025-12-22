-- PostgreSQL - iPhone Fiyat Tahmin Sistemi
-- 04) VIEW'LAR

-- V1) Specs katalog (tahmin ekranında seçim listesi)
CREATE OR REPLACE VIEW v_specs_catalog AS
SELECT
  s.specs_id,
  fn_specs_label(s.specs_id) AS label,
  m.model_id,
  m.model_name,
  ms.segment_name,
  m.release_year,
  s.ram_gb, s.kamera_mp, s.ekran_boyutu, s.batarya_mah, s.hafiza_gb
FROM specs s
JOIN models m ON m.model_id = s.model_id
JOIN model_segments ms ON ms.segment_id = m.segment_id;

-- V2) Modeller katalog
CREATE OR REPLACE VIEW v_models_catalog AS
SELECT
  m.model_id,
  m.model_name,
  ms.segment_name,
  m.release_year
FROM models m
JOIN model_segments ms ON ms.segment_id = m.segment_id;

-- V3) Segment katalog
CREATE OR REPLACE VIEW v_segments_catalog AS
SELECT segment_id, segment_name
FROM model_segments
ORDER BY segment_name;

-- V4) Cihaz durumu katalog (dropdown)
CREATE OR REPLACE VIEW v_condition_catalog AS
SELECT condition_id, condition_name
FROM device_condition
ORDER BY condition_id;

-- V5) Tahmin geçmişi detay (User ekranı için)
CREATE OR REPLACE VIEW v_prediction_history_detail AS
SELECT
  p.prediction_id,
  p.created_at,
  p.user_id,
  u.username,
  u.user_email,
  fn_specs_label(p.specs_id) AS specs_label,
  dc.condition_name,
  p.predicted_price,
  p.confidence_score
FROM predictions p
LEFT JOIN users u ON u.user_id = p.user_id
JOIN device_condition dc ON dc.condition_id = p.condition_id;

-- V6) Admin rapor: modele göre tahmin sayısı/ortalama/min/max
CREATE OR REPLACE VIEW v_admin_model_stats AS
SELECT
  m.model_name,
  ms.segment_name,
  m.release_year,
  count(*) AS total_predictions,
  avg(p.predicted_price) AS avg_price,
  min(p.predicted_price) AS min_price,
  max(p.predicted_price) AS max_price
FROM predictions p
JOIN specs s ON s.specs_id = p.specs_id
JOIN models m ON m.model_id = s.model_id
JOIN model_segments ms ON ms.segment_id = m.segment_id
GROUP BY m.model_name, ms.segment_name, m.release_year;

-- V7) Admin rapor: duruma göre tahmin istatistikleri
CREATE OR REPLACE VIEW v_admin_condition_stats AS
SELECT
  dc.condition_name,
  count(*) AS total_predictions,
  avg(p.predicted_price) AS avg_price
FROM predictions p
JOIN device_condition dc ON dc.condition_id = p.condition_id
GROUP BY dc.condition_name
ORDER BY total_predictions DESC;

-- V8) Maskeleme view: kullanıcı listesi (Admin/Analyst için)
CREATE OR REPLACE VIEW v_users_masked AS
SELECT
  user_id,
  fn_mask_username(username) AS username_masked,
  fn_mask_email(user_email)  AS email_masked,
  created_at
FROM users;


CREATE OR REPLACE VIEW v_user_history_masked AS
SELECT
  prediction_id,
  created_at,
  user_id,
  fn_mask_username(username) AS username_masked,
  specs_label,
  condition_name,
  predicted_price,
  confidence_score
FROM v_prediction_history_detail;

BEGIN;

DROP VIEW IF EXISTS v_specs_catalog;

CREATE VIEW v_specs_catalog AS
SELECT
  s.specs_id,
  (m.model_name || ' (' || m.release_year || ') - ' ||
   s.hafiza_gb || 'GB / ' ||
   s.ram_gb || 'GB RAM, ' ||
   s.kamera_mp || 'MP, ' ||
   s.ekran_boyutu || '", ' ||
   s.batarya_mah || 'mAh') AS label,
  m.model_name,
  seg.segment_name,
  m.release_year,
  s.ram_gb,
  s.kamera_mp,
  s.ekran_boyutu,
  s.batarya_mah,
  s.hafiza_gb
FROM specs s
JOIN models m ON m.model_id = s.model_id
JOIN model_segments seg ON seg.segment_id = m.segment_id;

COMMIT;
