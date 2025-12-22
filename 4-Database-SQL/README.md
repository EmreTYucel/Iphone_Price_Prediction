# PostgreSQL Veritabanı Kurulumu

## Kurulum Adımları

### 1. Veritabanı Oluşturma (pgAdmin veya psql ile)
```sql
CREATE DATABASE iphone_db;
```

### 2. SQL Dosyalarını Sırayla Çalıştırın

DataGrip, pgAdmin veya psql ile aşağıdaki sırayla çalıştırın:

| Sıra | Dosya | Açıklama |
|------|-------|----------|
| 1 | `01_createTable.sql` | 8 tablo oluşturur |
| 2 | `02_fonksiyon.sql` | 4 fonksiyon (maskeleme, label) |
| 3 | `03_storedprocedure.sql` | 8 stored procedure |
| 4 | `04_view.sql` | 9 view |
| 5 | `05_view_guncelleme.sql` | v_specs_catalog güncellemesi |
| 6 | `06_insert_data.sql` | Roller, segmentler, modeller, specs |
| 7 | `07_maskeleme.sql` | DB rol yetkilendirmesi |

### Bağlantı Bilgileri (db.js)
```javascript
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'iphone_db',
  password: 'postgres123',
  port: 5432,
});
```

### Veritabanı İçeriği

- **8 Tablo**: users, roles, user_role, model_segments, models, specs, device_condition, predictions
- **4 Fonksiyon**: fn_mask_email, fn_mask_username, fn_specs_label, fn_model_segment_name
- **8 SP**: sp_create_prediction, sp_admin_add_segment/model/specs/condition, sp_admin_update_model/specs, sp_admin_assign_role
- **9 View**: v_specs_catalog, v_models_catalog, v_segments_catalog, v_condition_catalog, v_prediction_history_detail, v_admin_model_stats, v_admin_condition_stats, v_users_masked, v_user_history_masked
- **28 Model**: iPhone 11-17 (Base, Mini, Plus, Pro, Pro Max)
- **85+ Specs**: Her model için farklı hafıza seçenekleri
