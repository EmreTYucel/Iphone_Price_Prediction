/* ============================================================
   AUTH + MASKING (Only Admin + User)
   PostgreSQL
   Proje: iPhone Fiyat Tahmin Sistemi (satış/ilan yok)

   Amaç:
   1) Yetkilendirme: Admin her şeyi yönetir; User yalnızca tahmin yapar ve kendi geçmişini görür.
   2) Maskeleme: User hassas kullanıcı verilerini (email/username/password_hash) asla düz görmez.
      - users tablosuna SELECT yetkisi verilmez
      - Maskeli görünüm view üzerinden sağlanır (v_user_history_masked vb.)
   ============================================================ */

BEGIN;

-- ============================================================
-- 0) Roller (DB role) oluşturma
-- ============================================================
-- Not: Bu DB rollerini uygulama kullanıcılarıyla karıştırmayın.
-- DB tarafında bağlantı yaparken admin bağlantıları app_admin ile,
-- normal kullanıcı bağlantıları app_user ile yapılır.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_admin') THEN
    CREATE ROLE app_admin;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_user') THEN
    CREATE ROLE app_user;
  END IF;
END $$;


-- ============================================================
-- 1) Varsayılan herkese açık yetkileri kapatma
-- ============================================================
-- Amaç: PUBLIC (herkes) hiçbir tabloyu, fonksiyonu veya prosedürü
-- doğrudan kullanamasın. Yetkiler sadece rollerle verilsin.
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL PROCEDURES IN SCHEMA public FROM PUBLIC;


-- ============================================================
-- 2) Admin yetkileri
-- ============================================================
-- Admin panelinde yapılacak işlemler:
-- - Segment/Model/Specs yönetimi
-- - Tahmin kayıtlarını görme
-- - Kullanıcı/Rol yönetimi
-- Bu nedenle admin'e tam yetki veriyoruz.
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_admin;

-- Fonksiyonlar ve prosedürler: Admin hepsini çalıştırabilir
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO app_admin;
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO app_admin;


-- ============================================================
-- 3) User yetkileri (en kritik bölüm)
-- ============================================================
-- User ekranında yapılacak işlemler:
-- - Tahmin ekranında specs seçme (v_specs_catalog)
-- - Tahmin ekranında cihaz durumu seçme (v_condition_catalog)
-- - Tahmin oluşturma (sp_create_prediction)
-- - Geçmiş ekranı görüntüleme (v_user_history_masked)
--
-- Güvenlik ilkesi:
-- - User tabloya değil view'a erişsin.
-- - users tablosu özellikle kapalı olsun (email/password_hash sızıntısı olmasın).


-- 3.1 users tablosunu user'dan tamamen kapat (maskelemenin temel garantisi)
REVOKE ALL ON users FROM app_user;

-- 3.2 Yönetim tablolarını da kapat (user admin işlevi görmesin)
REVOKE ALL ON roles FROM app_user;
REVOKE ALL ON user_role FROM app_user;
REVOKE ALL ON model_segments FROM app_user;
REVOKE ALL ON models FROM app_user;
REVOKE ALL ON specs FROM app_user;
REVOKE ALL ON device_condition FROM app_user;

-- predictions tablosunu da kapatmak iyi pratiktir.
-- Kullanıcı geçmişini view'dan göstereceğiz.
REVOKE ALL ON predictions FROM app_user;

-- 3.3 User için gerekli VIEW yetkileri
-- Not: Bu view'ların daha önce oluşturulmuş olması gerekir.
-- - v_specs_catalog: tahmin ekranı specs dropdown
-- - v_condition_catalog: tahmin ekranı condition dropdown
-- - v_user_history_masked: geçmiş ekranı (maskeli)
GRANT SELECT ON v_specs_catalog TO app_user;
GRANT SELECT ON v_condition_catalog TO app_user;
GRANT SELECT ON v_user_history_masked TO app_user;

-- (Opsiyonel) Eğer kullanıcıya "model listesi" de gösterecekseniz:
-- GRANT SELECT ON v_models_catalog TO app_user;

-- 3.4 User için gerekli PROCEDURE yetkisi (tahmin kaydı ekleme)
-- Kullanıcı uygulama tarafında ML sonucu aldıktan sonra bu prosedürü çağırır.
GRANT EXECUTE ON PROCEDURE sp_create_prediction(bigint,bigint,smallint,numeric,numeric) TO app_user;

-- 3.5 User'ın admin prosedürlerini çalıştırmasını engelle
-- (REVOKE çoğu zaman gerekmeyebilir ama raporda iyi durur)
REVOKE EXECUTE ON PROCEDURE sp_admin_add_segment(varchar) FROM app_user;
REVOKE EXECUTE ON PROCEDURE sp_admin_add_model(varchar,varchar,int) FROM app_user;
REVOKE EXECUTE ON PROCEDURE sp_admin_add_specs(bigint,int,int,numeric,int,int) FROM app_user;
REVOKE EXECUTE ON PROCEDURE sp_admin_update_model(bigint,varchar,varchar,int) FROM app_user;
REVOKE EXECUTE ON PROCEDURE sp_admin_update_specs(bigint,int,int,numeric,int,int) FROM app_user;
REVOKE EXECUTE ON PROCEDURE sp_admin_add_condition(varchar) FROM app_user;
REVOKE EXECUTE ON PROCEDURE sp_admin_assign_role(bigint,varchar) FROM app_user;
-- User'ın kullandığı view'lar fonksiyon çağırdığı için bu fonksiyonlara EXECUTE verilir:
GRANT EXECUTE ON FUNCTION fn_specs_label(bigint) TO app_user;
GRANT EXECUTE ON FUNCTION fn_mask_username(text) TO app_user;
GRANT EXECUTE ON FUNCTION fn_mask_email(text) TO app_user;

-- (Opsiyonel) Eğer başka view'larda kullanıyorsanız:
GRANT EXECUTE ON FUNCTION fn_model_segment_name(bigint) TO app_user;



-- ============================================================
-- 4) Maskeleme yaklaşımının açıklaması (SQL ile ispat)
-- ============================================================
-- Maskeleme, kullanıcıya doğrudan tabloyu açmak yerine,
-- maskeli view üzerinden göstererek sağlanır:
--
-- - users tablosu app_user için kapalı (REVOKE ALL ON users)
-- - user geçmiş ekranı: v_user_history_masked view
--   Bu view içerisinde username/email maskelenerek dönmelidir.
--
-- Örn: v_user_history_masked şu mantığa dayanır:
--   - fn_mask_username(username)
--   - fn_mask_email(user_email)
--
-- Böylece user, hiçbir koşulda users.user_email veya users.password_hash
-- alanlarını düz şekilde çekemez.


-- ============================================================
-- 5) (Güçlendirme) View güvenliği: owner yaklaşımı
-- ============================================================
-- Not: PostgreSQL'de view'lar varsayılan olarak owner yetkileri ile çalışmaz.
-- Burada amacımız user'ın sadece view üzerinden okuma yapmasını sağlamak.
-- Zaten users tablosunu user'dan kapattığımız için bypass edemez.
--
-- Eğer view'larınız users tablosuna join yapıyorsa:
-- - View owner'ı admin olmalı (app_admin değil, DB sahibi kullanıcı)
-- - User sadece view'a SELECT almalı
-- Bu pratikte yeterlidir.

COMMIT;

/* ============================================================
   Uygulama/UI tarafı kullanım notları
   ------------------------------------------------------------
   USER (app_user ile bağlanır):
   - Tahmin ekranı specs:
     SELECT specs_id, label FROM v_specs_catalog;

   - Tahmin ekranı durum:
     SELECT condition_id, condition_name FROM v_condition_catalog;

   - Tahmin sonucu kaydı:
     CALL sp_create_prediction(<user_id>, <specs_id>, <condition_id>, <price>, <confidence>);

   - Geçmiş ekranı:
     SELECT * FROM v_user_history_masked ORDER BY created_at DESC;

   ADMIN (app_admin ile bağlanır):
   - Admin tüm tablolara / view'lara / SP'lere erişir.
   - Kullanıcı yönetimi, model-segment-spec ekleme/güncelleme vs. işlemlerini yapar.
   ============================================================ */

