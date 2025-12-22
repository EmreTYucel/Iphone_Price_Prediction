-- PostgreSQL - iPhone Fiyat Tahmin Sistemi
-- 02) FONKSİYONLAR

-- F1) Email maskeleme
CREATE OR REPLACE FUNCTION fn_mask_email(p_email text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_email IS NULL THEN NULL
    ELSE regexp_replace(p_email, '(^.).*(@.*$)', '\1***\2')
  END;
$$;

-- F2) Username maskeleme
CREATE OR REPLACE FUNCTION fn_mask_username(p_username text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_username IS NULL THEN NULL
    ELSE left(p_username, 2) || repeat('*', greatest(length(p_username) - 2, 0))
  END;
$$;

-- F3) Specs için okunabilir etiket (UI dropdown için)
CREATE OR REPLACE FUNCTION fn_specs_label(p_specs_id bigint)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT
    m.model_name || ' ' || ms.segment_name || ' (' || m.release_year || ') - ' ||
    s.hafiza_gb || 'GB / ' || s.ram_gb || 'GB RAM, ' ||
    s.kamera_mp || 'MP, ' || s.ekran_boyutu || '", ' ||
    s.batarya_mah || 'mAh'
  FROM specs s
  JOIN models m ON m.model_id = s.model_id
  JOIN model_segments ms ON ms.segment_id = m.segment_id
  WHERE s.specs_id = p_specs_id;
$$;

-- F4) Segment adını model_id ile döndürme (rapor/view içinde iş görür)
CREATE OR REPLACE FUNCTION fn_model_segment_name(p_model_id bigint)
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT ms.segment_name
  FROM models m
  JOIN model_segments ms ON ms.segment_id = m.segment_id
  WHERE m.model_id = p_model_id;
$$;
