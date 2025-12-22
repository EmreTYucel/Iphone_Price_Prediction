/* ============================================================
   06_insert_data.sql  (PostgreSQL)
   iPhone Fiyat Tahmin Sistemi - Başlangıç verileri
   - roles: Admin, User
   - model_segments: Base, Mini, Plus, Pro, Pro Max
   - device_condition: Mükemmel, Çok İyi, İyi, Outlet
   - Models: iPhone 8 .. iPhone 16 (v15 Dataset Bazlı)
   ============================================================ */



-- 1) ROLES
INSERT INTO roles(role_name)
VALUES
  ('Admin'),
  ('User')
ON CONFLICT (role_name) DO NOTHING;

-- 2) MODEL_SEGMENTS
INSERT INTO model_segments(segment_name)
VALUES
  ('Base'),
  ('Mini'),
  ('Plus'),
  ('Pro'),
  ('Pro Max')
ON CONFLICT (segment_name) DO NOTHING;

-- 3) DEVICE_CONDITION (User request: Mükemmel, Çok İyi, İyi, Outlet)
-- Not: Eski değerler (Orta, Kötü) varsa kalabilir, ancak yeni UI sadece bunlari kullanacak.
INSERT INTO device_condition(condition_name)
VALUES
  ('Mükemmel'),
  ('Çok İyi'),
  ('İyi'),
  ('Outlet')
ON CONFLICT (condition_name) DO NOTHING;

-- 4) MODELS (iPhone 8 ... iPhone 16)
-- v15 Dataset Analysis:
-- iPhone 8, 8 Plus
-- iPhone X, XR, XS, XS Max
-- iPhone 11, 11 Pro, 11 Pro Max
-- iPhone SE (2020), SE (2022)
-- iPhone 12, Mini, Pro, Pro Max
-- iPhone 13, Mini, Pro, Pro Max
-- iPhone 14, Plus, Pro, Pro Max
-- iPhone 15, Plus, Pro, Pro Max
-- iPhone 16, Plus, Pro, Pro Max

WITH model_seed(model_name, segment_name, release_year) AS (
  VALUES
    -- iPhone 8 Series (2017) - "Plus" is inferred if name was distinct, but dataset treats "iPhone 8" with 5.5 screen as Plus usually. 
    -- Dataset simplifies names to "Apple iPhone 8". We will seed distinct base models.
    ('iPhone 8',         'Base',    2017),
    ('iPhone 8 Plus',    'Plus',    2017), -- 5.5 inch screen in dataset implies Plus
    
    -- iPhone X Series (2017/2018)
    ('iPhone X',         'Pro',     2017), -- X was the premium
    ('iPhone XR',        'Base',    2018),
    ('iPhone XS',        'Pro',     2018),
    ('iPhone XS Max',    'Pro Max', 2018),

    -- iPhone 11 Series (2019)
    ('iPhone 11',        'Base',    2019),
    ('iPhone 11 Pro',    'Pro',     2019),
    ('iPhone 11 Pro Max','Pro Max', 2019),

    -- iPhone SE
    ('iPhone SE 2020',   'Base',    2020),
    ('iPhone SE 2022',   'Base',    2022),

    -- iPhone 12 Series (2020)
    ('iPhone 12',        'Base',    2020),
    ('iPhone 12 mini',   'Mini',    2020),
    ('iPhone 12 Pro',    'Pro',     2020),
    ('iPhone 12 Pro Max','Pro Max', 2020),

    -- iPhone 13 Series (2021)
    ('iPhone 13',        'Base',    2021),
    ('iPhone 13 mini',   'Mini',    2021),
    ('iPhone 13 Pro',    'Pro',     2021),
    ('iPhone 13 Pro Max','Pro Max', 2021),

    -- iPhone 14 Series (2022)
    ('iPhone 14',        'Base',    2022),
    ('iPhone 14 Plus',   'Plus',    2022),
    ('iPhone 14 Pro',    'Pro',     2022),
    ('iPhone 14 Pro Max','Pro Max', 2022),

    -- iPhone 15 Series (2023)
    ('iPhone 15',        'Base',    2023),
    ('iPhone 15 Plus',   'Plus',    2023),
    ('iPhone 15 Pro',    'Pro',     2023),
    ('iPhone 15 Pro Max','Pro Max', 2023),

    -- iPhone 16 Series (2024)
    ('iPhone 16',        'Base',    2024),
    ('iPhone 16 Plus',   'Plus',    2024),
    ('iPhone 16 Pro',    'Pro',     2024),
    ('iPhone 16 Pro Max','Pro Max', 2024)
)
INSERT INTO models(model_name, segment_id, release_year)
SELECT ms.model_name, seg.segment_id, ms.release_year
FROM model_seed ms
JOIN model_segments seg ON seg.segment_name = ms.segment_name
ON CONFLICT (model_name, segment_id, release_year) DO NOTHING;


-- 5) SPECS
-- Derived from birlesmis_tam_datasetv15.csv
WITH specs_seed(
  model_name, segment_name, release_year,
  ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb
) AS (
  VALUES
    -- iPhone 8 (4.7", 1821mAh, 2GB RAM)
    ('iPhone 8', 'Base', 2017, 2, 12, 4.7, 1821, 64),
    ('iPhone 8', 'Base', 2017, 2, 12, 4.7, 1821, 128),
    ('iPhone 8', 'Base', 2017, 2, 12, 4.7, 1821, 256),
    
    -- iPhone 8 Plus (5.5", 2691mAh, 3GB RAM) - In dataset as "Apple iPhone 8" with 5.5 screen
    ('iPhone 8 Plus', 'Plus', 2017, 3, 12, 5.5, 2691, 64),
    ('iPhone 8 Plus', 'Plus', 2017, 3, 12, 5.5, 2691, 128),
    ('iPhone 8 Plus', 'Plus', 2017, 3, 12, 5.5, 2691, 256),

    -- iPhone SE 2020 (4.7", 1821mAh, 3GB RAM)
    ('iPhone SE 2020', 'Base', 2020, 3, 12, 4.7, 1821, 64),
    ('iPhone SE 2020', 'Base', 2020, 3, 12, 4.7, 1821, 128),
    ('iPhone SE 2020', 'Base', 2020, 3, 12, 4.7, 1821, 256),

    -- iPhone SE 2022 (4.7", 2018mAh, 4GB RAM) - Dataset lists 1821mah? Adjusting to dataset value if needed, but 2018 is correct for SE3. Dataset line 61 says 1821... We will use dataset value to match for now if required? 
    -- Actually dataset line 61: "Apple iPhone SE 2022... 1821.0". Wait, SE3 has larger battery? Dataset says 1821. trusting dataset.
    ('iPhone SE 2022', 'Base', 2022, 4, 12, 4.7, 1821, 64),
    ('iPhone SE 2022', 'Base', 2022, 4, 12, 4.7, 1821, 128),
    ('iPhone SE 2022', 'Base', 2022, 4, 12, 4.7, 1821, 256),

    -- iPhone X (5.8", 2716mAh, 3GB RAM)
    ('iPhone X', 'Pro', 2017, 3, 12, 5.8, 2716, 64),
    ('iPhone X', 'Pro', 2017, 3, 12, 5.8, 2716, 256),

    -- iPhone XR (6.1", 2942mAh, 3GB RAM) - Dataset line 24 says "2716" for XR?? Line 43 says 2716. iPhone X battery is 2716. XR is usually 2942. 
    -- User said "use dataset". I will use 2716 if that is what csv says...
    ('iPhone XR', 'Base', 2018, 3, 12, 6.1, 2716, 64),
    ('iPhone XR', 'Base', 2018, 3, 12, 6.1, 2716, 128),
    ('iPhone XR', 'Base', 2018, 3, 12, 6.1, 2716, 256),

    -- iPhone XS (5.8", 2658mAh, 4GB RAM) - Dataset line 41 says 2716.
    ('iPhone XS', 'Pro', 2018, 4, 12, 5.8, 2716, 64),
    ('iPhone XS', 'Pro', 2018, 4, 12, 5.8, 2716, 256),
    ('iPhone XS', 'Pro', 2018, 4, 12, 5.8, 2716, 512),

    -- iPhone 11 (6.1", 3110mAh, 4GB RAM)
    ('iPhone 11', 'Base', 2019, 4, 12, 6.1, 3110, 64),
    ('iPhone 11', 'Base', 2019, 4, 12, 6.1, 3110, 128),
    ('iPhone 11', 'Base', 2019, 4, 12, 6.1, 3110, 256),

    -- iPhone 11 Pro (5.8", 3046, 4GB)
    ('iPhone 11 Pro', 'Pro', 2019, 4, 12, 5.8, 3046, 64),
    ('iPhone 11 Pro', 'Pro', 2019, 4, 12, 5.8, 3046, 256),
    ('iPhone 11 Pro', 'Pro', 2019, 4, 12, 5.8, 3046, 512),

    -- iPhone 11 Pro Max (6.5", 3969, 4GB)
    ('iPhone 11 Pro Max', 'Pro Max', 2019, 4, 12, 6.5, 3969, 64),
    ('iPhone 11 Pro Max', 'Pro Max', 2019, 4, 12, 6.5, 3969, 256),
    ('iPhone 11 Pro Max', 'Pro Max', 2019, 4, 12, 6.5, 3969, 512),

    -- iPhone 12 (6.1", 2815, 4GB)
    ('iPhone 12', 'Base', 2020, 4, 12, 6.1, 2815, 64),
    ('iPhone 12', 'Base', 2020, 4, 12, 6.1, 2815, 128),
    ('iPhone 12', 'Base', 2020, 4, 12, 6.1, 2815, 256),

    -- iPhone 12 Mini (5.4", 2227, 4GB)
    ('iPhone 12 mini', 'Mini', 2020, 4, 12, 5.4, 2227, 64),
    ('iPhone 12 mini', 'Mini', 2020, 4, 12, 5.4, 2227, 128),
    ('iPhone 12 mini', 'Mini', 2020, 4, 12, 5.4, 2227, 256),

    -- iPhone 12 Pro (6.1", 2815, 6GB)
    ('iPhone 12 Pro', 'Pro', 2020, 6, 12, 6.1, 2815, 128),
    ('iPhone 12 Pro', 'Pro', 2020, 6, 12, 6.1, 2815, 256),
    ('iPhone 12 Pro', 'Pro', 2020, 6, 12, 6.1, 2815, 512),

    -- iPhone 12 Pro Max (6.7", 3687, 6GB)
    ('iPhone 12 Pro Max', 'Pro Max', 2020, 6, 12, 6.7, 3687, 128),
    ('iPhone 12 Pro Max', 'Pro Max', 2020, 6, 12, 6.7, 3687, 256),
    ('iPhone 12 Pro Max', 'Pro Max', 2020, 6, 12, 6.7, 3687, 512),

    -- iPhone 13 (6.1", 3227 - Dataset says 3227/3095?, 4GB)
    ('iPhone 13', 'Base', 2021, 4, 12, 6.1, 3227, 128),
    ('iPhone 13', 'Base', 2021, 4, 12, 6.1, 3227, 256),
    ('iPhone 13', 'Base', 2021, 4, 12, 6.1, 3227, 512),

    -- iPhone 13 Mini (5.4", 2406, 4GB)
    ('iPhone 13 mini', 'Mini', 2021, 4, 12, 5.4, 2406, 128),
    ('iPhone 13 mini', 'Mini', 2021, 4, 12, 5.4, 2406, 256),
    ('iPhone 13 mini', 'Mini', 2021, 4, 12, 5.4, 2406, 512),

    -- iPhone 13 Pro (6.1", 3095, 6GB)
    ('iPhone 13 Pro', 'Pro', 2021, 6, 12, 6.1, 3095, 128),
    ('iPhone 13 Pro', 'Pro', 2021, 6, 12, 6.1, 3095, 256),
    ('iPhone 13 Pro', 'Pro', 2021, 6, 12, 6.1, 3095, 512),
    ('iPhone 13 Pro', 'Pro', 2021, 6, 12, 6.1, 3095, 1024),

    -- iPhone 13 Pro Max (6.7", 4352, 6GB)
    ('iPhone 13 Pro Max', 'Pro Max', 2021, 6, 12, 6.7, 4352, 128),
    ('iPhone 13 Pro Max', 'Pro Max', 2021, 6, 12, 6.7, 4352, 256),
    ('iPhone 13 Pro Max', 'Pro Max', 2021, 6, 12, 6.7, 4352, 512),
    ('iPhone 13 Pro Max', 'Pro Max', 2021, 6, 12, 6.7, 4352, 1024),

    -- iPhone 14 (6.1", 3279, 6GB)
    ('iPhone 14', 'Base', 2022, 6, 12, 6.1, 3279, 128),
    ('iPhone 14', 'Base', 2022, 6, 12, 6.1, 3279, 256),
    ('iPhone 14', 'Base', 2022, 6, 12, 6.1, 3279, 512),

    -- iPhone 14 Plus (6.7", 4325, 6GB)
    ('iPhone 14 Plus', 'Plus', 2022, 6, 12, 6.7, 4325, 128),
    ('iPhone 14 Plus', 'Plus', 2022, 6, 12, 6.7, 4325, 256),
    ('iPhone 14 Plus', 'Plus', 2022, 6, 12, 6.7, 4325, 512),

    -- iPhone 14 Pro (6.1", 3200, 6GB, 48MP)
    ('iPhone 14 Pro', 'Pro', 2022, 6, 48, 6.1, 3200, 128),
    ('iPhone 14 Pro', 'Pro', 2022, 6, 48, 6.1, 3200, 256),
    ('iPhone 14 Pro', 'Pro', 2022, 6, 48, 6.1, 3200, 512),
    ('iPhone 14 Pro', 'Pro', 2022, 6, 48, 6.1, 3200, 1024),

    -- iPhone 14 Pro Max (6.7", 4323, 6GB)
    ('iPhone 14 Pro Max', 'Pro Max', 2022, 6, 48, 6.7, 4323, 128),
    ('iPhone 14 Pro Max', 'Pro Max', 2022, 6, 48, 6.7, 4323, 256),
    ('iPhone 14 Pro Max', 'Pro Max', 2022, 6, 48, 6.7, 4323, 512),
    ('iPhone 14 Pro Max', 'Pro Max', 2022, 6, 48, 6.7, 4323, 1024),

    -- iPhone 15 (6.1", 3349, 6GB, 48MP)
    ('iPhone 15', 'Base', 2023, 6, 48, 6.1, 3349, 128),
    ('iPhone 15', 'Base', 2023, 6, 48, 6.1, 3349, 256),
    ('iPhone 15', 'Base', 2023, 6, 48, 6.1, 3349, 512),

    -- iPhone 15 Plus (6.7", 4383, 6GB)
    ('iPhone 15 Plus', 'Plus', 2023, 6, 48, 6.7, 4383, 128),
    ('iPhone 15 Plus', 'Plus', 2023, 6, 48, 6.7, 4383, 256),
    ('iPhone 15 Plus', 'Plus', 2023, 6, 48, 6.7, 4383, 512),

    -- iPhone 15 Pro (6.1", 3274, 8GB)
    ('iPhone 15 Pro', 'Pro', 2023, 8, 48, 6.1, 3274, 128),
    ('iPhone 15 Pro', 'Pro', 2023, 8, 48, 6.1, 3274, 256),
    ('iPhone 15 Pro', 'Pro', 2023, 8, 48, 6.1, 3274, 512),
    ('iPhone 15 Pro', 'Pro', 2023, 8, 48, 6.1, 3274, 1024),

    -- iPhone 15 Pro Max (6.7", 4422, 8GB)
    ('iPhone 15 Pro Max', 'Pro Max', 2023, 8, 48, 6.7, 4422, 256),
    ('iPhone 15 Pro Max', 'Pro Max', 2023, 8, 48, 6.7, 4422, 512),
    ('iPhone 15 Pro Max', 'Pro Max', 2023, 8, 48, 6.7, 4422, 1024),

    -- iPhone 16 (6.1", 3561, 8GB) - From dataset
    ('iPhone 16', 'Base', 2024, 8, 48, 6.1, 3561, 128),
    ('iPhone 16', 'Base', 2024, 8, 48, 6.1, 3561, 256),
    ('iPhone 16', 'Base', 2024, 8, 48, 6.1, 3561, 512),

    -- iPhone 16 Plus (6.7", 4674, 8GB)
    ('iPhone 16 Plus', 'Plus', 2024, 8, 48, 6.7, 4674, 128),
    ('iPhone 16 Plus', 'Plus', 2024, 8, 48, 6.7, 4674, 256),
    ('iPhone 16 Plus', 'Plus', 2024, 8, 48, 6.7, 4674, 512),

    -- iPhone 16 Pro (6.3", 3582, 8GB)
    ('iPhone 16 Pro', 'Pro', 2024, 8, 48, 6.3, 3582, 128),
    ('iPhone 16 Pro', 'Pro', 2024, 8, 48, 6.3, 3582, 256),
    ('iPhone 16 Pro', 'Pro', 2024, 8, 48, 6.3, 3582, 512),
    ('iPhone 16 Pro', 'Pro', 2024, 8, 48, 6.3, 3582, 1024), -- Assuming 1TB exists

    -- iPhone 16 Pro Max (6.9", 4685, 8GB)
    ('iPhone 16 Pro Max', 'Pro Max', 2024, 8, 48, 6.9, 4685, 256),
    ('iPhone 16 Pro Max', 'Pro Max', 2024, 8, 48, 6.9, 4685, 512),
    ('iPhone 16 Pro Max', 'Pro Max', 2024, 8, 48, 6.9, 4685, 1024)
),
resolved AS (
  SELECT
    ss.*,
    m.model_id
  FROM specs_seed ss
  JOIN model_segments seg ON seg.segment_name = ss.segment_name
  JOIN models m
    ON m.model_name = ss.model_name
   AND m.segment_id = seg.segment_id
   AND m.release_year = ss.release_year
)
INSERT INTO specs(model_id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb)
SELECT model_id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb
FROM resolved
ON CONFLICT (model_id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb) DO NOTHING;


