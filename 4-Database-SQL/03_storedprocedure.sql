/* ============================================================
   iPhone Fiyat Tahmin Sistemi - Stored Procedures (8 adet)
   PostgreSQL
 
   ============================================================ */

-- ============================================================
-- SP1) User: Tahmin kaydı oluşturma
-- UI: Kullanıcı "Tahmin Et" -> ML fiyatı üretir -> DB'ye kaydedilir
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_create_prediction(
  p_user_id bigint,
  p_specs_id bigint,
  p_condition_id smallint,
  p_predicted_price numeric,
  p_confidence_score numeric DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Basit iş kuralı: fiyat pozitif olmalı
  IF p_predicted_price <= 0 THEN
    RAISE EXCEPTION 'predicted_price must be > 0';
  END IF;

  INSERT INTO predictions(specs_id, user_id, condition_id, predicted_price, confidence_score)
  VALUES (p_specs_id, p_user_id, p_condition_id, p_predicted_price, p_confidence_score);
END;
$$;


-- ============================================================
-- SP2) Admin: Segment ekleme (idempotent)
-- UI: Admin -> Segment Yönetimi -> "Ekle"
-- Not: Segment zaten varsa hata vermeden geçer
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_admin_add_segment(
  p_segment_name varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO model_segments(segment_name)
  VALUES (p_segment_name);
EXCEPTION
  WHEN unique_violation THEN
    NULL; -- zaten var
END;
$$;


-- ============================================================
-- SP3) Admin: Model ekleme
-- UI: Admin -> Model Yönetimi -> "Model Ekle"
-- Not: Segment adı üzerinden segment_id bulunur; yoksa hata verilir
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_admin_add_model(
  p_model_name varchar,
  p_segment_name varchar,
  p_release_year int
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_segment_id smallint;
BEGIN
  SELECT segment_id INTO v_segment_id
  FROM model_segments
  WHERE segment_name = p_segment_name;

  IF v_segment_id IS NULL THEN
    RAISE EXCEPTION 'Segment bulunamadı: %', p_segment_name;
  END IF;

  INSERT INTO models(model_name, segment_id, release_year)
  VALUES (p_model_name, v_segment_id, p_release_year);
END;
$$;


-- ============================================================
-- SP4) Admin: Specs ekleme
-- UI: Admin -> Specs Yönetimi -> "Specs Ekle"
-- Not: Aynı kombinasyon varsa UNIQUE constraint engeller
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_admin_add_specs(
  p_model_id bigint,
  p_ram_gb int,
  p_kamera_mp int,
  p_ekran_boyutu numeric,
  p_batarya_mah int,
  p_hafiza_gb int
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO specs(model_id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb)
  VALUES (p_model_id, p_ram_gb, p_kamera_mp, p_ekran_boyutu, p_batarya_mah, p_hafiza_gb);
END;
$$;


-- ============================================================
-- SP5) Admin: Model güncelleme
-- UI: Admin -> Model Yönetimi -> "Düzenle / Güncelle"
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_admin_update_model(
  p_model_id bigint,
  p_model_name varchar,
  p_segment_name varchar,
  p_release_year int
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_segment_id smallint;
BEGIN
  SELECT segment_id INTO v_segment_id
  FROM model_segments
  WHERE segment_name = p_segment_name;

  IF v_segment_id IS NULL THEN
    RAISE EXCEPTION 'Segment bulunamadı: %', p_segment_name;
  END IF;

  UPDATE models
  SET model_name = p_model_name,
      segment_id = v_segment_id,
      release_year = p_release_year
  WHERE model_id = p_model_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Model bulunamadı: %', p_model_id;
  END IF;
END;
$$;


-- ============================================================
-- SP6) Admin: Specs güncelleme
-- UI: Admin -> Specs Yönetimi -> "Düzenle / Güncelle"
-- Not: Güncellenen kombinasyon başka satırla çakışırsa UNIQUE engeller
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_admin_update_specs(
  p_specs_id bigint,
  p_ram_gb int,
  p_kamera_mp int,
  p_ekran_boyutu numeric,
  p_batarya_mah int,
  p_hafiza_gb int
)
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE specs
  SET ram_gb = p_ram_gb,
      kamera_mp = p_kamera_mp,
      ekran_boyutu = p_ekran_boyutu,
      batarya_mah = p_batarya_mah,
      hafiza_gb = p_hafiza_gb
  WHERE specs_id = p_specs_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Specs bulunamadı: %', p_specs_id;
  END IF;
END;
$$;


-- ============================================================
-- SP7) Admin: Cihaz durumu ekleme (idempotent)
-- UI: Admin -> Durum Yönetimi -> "Ekle"
-- Not: Durum zaten varsa hata vermeden geçer
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_admin_add_condition(
  p_condition_name varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO device_condition(condition_name)
  VALUES (p_condition_name);
EXCEPTION
  WHEN unique_violation THEN
    NULL; -- zaten var
END;
$$;


-- ============================================================
-- SP8) Admin: Kullanıcıya rol atama (Admin/User)
-- UI: Admin -> Kullanıcı Yönetimi -> "Rol Ata"
-- Not: Aynı rol daha önce atanmışsa ON CONFLICT ile tekrar eklemez
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_admin_assign_role(
  p_user_id bigint,
  p_role_name varchar
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_role_id smallint;
BEGIN
  SELECT role_id INTO v_role_id
  FROM roles
  WHERE role_name = p_role_name;

  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Role bulunamadı: %', p_role_name;
  END IF;

  INSERT INTO user_role(user_id, role_id)
  VALUES (p_user_id, v_role_id)
  ON CONFLICT DO NOTHING;
END;
$$;

