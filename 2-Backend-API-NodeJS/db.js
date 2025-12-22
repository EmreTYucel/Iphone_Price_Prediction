const { Pool } = require('pg');

// PostgreSQL bağlantı havuzu yapılandırması
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'iphone_db',
  password: '12345',
  port: 5432,
});

// Temel sorgu fonksiyonu
const query = (text, params) => pool.query(text, params);

// ============================================================
// VIEW ÇAĞIRMA FONKSİYONLARI
// ============================================================

// V1: Specs katalog listesi (tahmin dropdown için)
const getSpecsCatalog = async () => {
  const result = await pool.query('SELECT * FROM v_specs_catalog ORDER BY model_name, segment_name');
  return result.rows;
};

// V2: Model katalog listesi
const getModelsCatalog = async () => {
  const result = await pool.query('SELECT * FROM v_models_catalog ORDER BY model_name, segment_name');
  return result.rows;
};

// V3: Segment katalog listesi
const getSegmentsCatalog = async () => {
  const result = await pool.query('SELECT * FROM v_segments_catalog');
  return result.rows;
};

// V4: Cihaz durumu katalog listesi
const getConditionCatalog = async () => {
  const result = await pool.query('SELECT * FROM v_condition_catalog');
  return result.rows;
};

// V5: Tahmin geçmişi detay (tüm kullanıcılar - Admin için)
const getPredictionHistoryDetail = async () => {
  const result = await pool.query('SELECT * FROM v_prediction_history_detail ORDER BY created_at DESC');
  return result.rows;
};

// V5b: Belirli kullanıcının tahmin geçmişi
const getUserPredictionHistory = async (userId) => {
  const result = await pool.query(
    'SELECT * FROM v_prediction_history_detail WHERE user_id = $1 ORDER BY created_at DESC',
    [userId]
  );
  return result.rows;
};

// V6: Admin model istatistikleri
const getAdminModelStats = async () => {
  const result = await pool.query('SELECT * FROM v_admin_model_stats ORDER BY total_predictions DESC');
  return result.rows;
};

// V7: Admin durum istatistikleri
const getAdminConditionStats = async () => {
  const result = await pool.query('SELECT * FROM v_admin_condition_stats');
  return result.rows;
};

// V8: Maskeli kullanıcı listesi
// V8: Maskeli kullanıcı listesi (Rollerle birlikte - Tekil satır)
const getUsersMasked = async () => {
  const result = await pool.query(`
    SELECT v.user_id, v.username_masked, v.email_masked, v.created_at, 
           COALESCE(STRING_AGG(DISTINCT r.role_name, ', '), 'User') as role_name 
    FROM v_users_masked v
    LEFT JOIN user_role ur ON v.user_id = ur.user_id 
    LEFT JOIN roles r ON ur.role_id = r.role_id 
    GROUP BY v.user_id, v.username_masked, v.email_masked, v.created_at
    ORDER BY v.created_at DESC
  `);
  return result.rows;
};

// V9: Maskeli tahmin geçmişi
const getUserHistoryMasked = async () => {
  const result = await pool.query('SELECT * FROM v_user_history_masked ORDER BY created_at DESC');
  return result.rows;
};

// ============================================================
// STORED PROCEDURE ÇAĞIRMA FONKSİYONLARI (8 SP)
// ============================================================

// SP1: Tahmin kaydı oluştur
const createPrediction = async (userId, specsId, conditionId, predictedPrice, confidenceScore = null) => {
  await pool.query(
    'CALL sp_create_prediction($1, $2, $3, $4, $5)',
    [userId, specsId, conditionId, predictedPrice, confidenceScore]
  );
  return { success: true, message: 'Tahmin kaydedildi' };
};

// SP2: Segment ekle (Admin)
const addSegment = async (segmentName) => {
  await pool.query('CALL sp_admin_add_segment($1)', [segmentName]);
  return { success: true, message: 'Segment eklendi' };
};

// SP3: Model ekle (Admin)
const addModel = async (modelName, segmentName, releaseYear) => {
  await pool.query('CALL sp_admin_add_model($1, $2, $3)', [modelName, segmentName, releaseYear]);
  return { success: true, message: 'Model eklendi' };
};

// SP4: Specs ekle (Admin)
const addSpecs = async (modelId, ramGb, kameraMp, ekranBoyutu, bataryaMah, hafizaGb) => {
  await pool.query(
    'CALL sp_admin_add_specs($1, $2, $3, $4, $5, $6)',
    [modelId, ramGb, kameraMp, ekranBoyutu, bataryaMah, hafizaGb]
  );
  return { success: true, message: 'Specs eklendi' };
};

// SP5: Model güncelle (Admin)
const updateModel = async (modelId, modelName, segmentName, releaseYear) => {
  await pool.query(
    'CALL sp_admin_update_model($1, $2, $3, $4)',
    [modelId, modelName, segmentName, releaseYear]
  );
  return { success: true, message: 'Model güncellendi' };
};

// SP6: Specs güncelle (Admin)
const updateSpecs = async (specsId, ramGb, kameraMp, ekranBoyutu, bataryaMah, hafizaGb) => {
  await pool.query(
    'CALL sp_admin_update_specs($1, $2, $3, $4, $5, $6)',
    [specsId, ramGb, kameraMp, ekranBoyutu, bataryaMah, hafizaGb]
  );
  return { success: true, message: 'Specs güncellendi' };
};

// SP7: Condition ekle (Admin)
const addCondition = async (conditionName) => {
  await pool.query('CALL sp_admin_add_condition($1)', [conditionName]);
  return { success: true, message: 'Durum eklendi' };
};

// SP8: Kullanıcıya rol ata (Admin) -> Tekil fol politikası (Eskileri siler)
const assignRole = async (userId, roleName) => {
  const uid = parseInt(userId);
  if (Number.isNaN(uid)) throw new Error('Invalid user id for role assignment');
  const rName = String(roleName);
  console.log('db.assignRole called with:', { uid, uidType: typeof uid, rName, rNameType: typeof rName });

  // Önce kullanıcının mevcut rollerini temizle (Tekil rol politikası)
  await pool.query('DELETE FROM user_role WHERE user_id = $1', [uid]);

  // Yeni rolü ata
  await pool.query('CALL sp_admin_assign_role($1, $2)', [uid, rName]);
  return { success: true, message: 'Rol atandı' };
};

// ============================================================
// FONKSİYON ÇAĞIRMA (4 Fonksiyon)
// ============================================================

// F1: Email maskeleme
const maskEmail = async (email) => {
  const result = await pool.query('SELECT fn_mask_email($1) as masked', [email]);
  return result.rows[0].masked;
};

// F2: Username maskeleme
const maskUsername = async (username) => {
  const result = await pool.query('SELECT fn_mask_username($1) as masked', [username]);
  return result.rows[0].masked;
};

// F3: Specs label al
const getSpecsLabel = async (specsId) => {
  const result = await pool.query('SELECT fn_specs_label($1) as label', [specsId]);
  return result.rows[0].label;
};

// F4: Model segment adı al
const getModelSegmentName = async (modelId) => {
  const result = await pool.query('SELECT fn_model_segment_name($1) as segment_name', [modelId]);
  return result.rows[0].segment_name;
};

// ============================================================
// CRUD İŞLEMLERİ (Direkt SQL)
// ============================================================

// Users CRUD
const getUsers = async () => {
  const result = await pool.query('SELECT user_id, username, user_email, created_at FROM users ORDER BY created_at DESC');
  return result.rows;
};

const getUserById = async (userId) => {
  const result = await pool.query(
    `SELECT u.user_id, u.username, u.user_email, u.created_at, array_agg(r.role_name) as roles
     FROM users u
     LEFT JOIN user_role ur ON u.user_id = ur.user_id
     LEFT JOIN roles r ON ur.role_id = r.role_id
     WHERE u.user_id = $1
     GROUP BY u.user_id`,
    [userId]
  );
  return result.rows[0];
};

// Auth için: kullanıcıyı parola hash'iyle birlikte getir
const getAuthUserByUsername = async (username) => {
  const result = await pool.query(
    `SELECT u.user_id, u.username, u.password_hash, u.user_email, u.created_at, array_agg(r.role_name) as roles
     FROM users u
     LEFT JOIN user_role ur ON u.user_id = ur.user_id
     LEFT JOIN roles r ON ur.role_id = r.role_id
     WHERE u.username = $1
     GROUP BY u.user_id`,
    [username]
  );
  return result.rows[0];
};

const getUserByUsername = async (username) => {
  // Genel kullanım için parola içermeyen versiyon
  const result = await pool.query(
    `SELECT u.user_id, u.username, u.user_email, u.created_at, array_agg(r.role_name) as roles
     FROM users u
     LEFT JOIN user_role ur ON u.user_id = ur.user_id
     LEFT JOIN roles r ON ur.role_id = r.role_id
     WHERE u.username = $1
     GROUP BY u.user_id`,
    [username]
  );
  return result.rows[0];
};

const createUser = async (username, passwordHash, email) => {
  const result = await pool.query(
    'INSERT INTO users(username, password_hash, user_email) VALUES($1, $2, $3) RETURNING user_id',
    [username, passwordHash, email]
  );

  // Eğer veritabanında hiç Admin yoksa bu kullanıcıyı Admin yap, aksi halde User yap
  const adminCheck = await pool.query(
    "SELECT 1 FROM user_role ur JOIN roles r ON ur.role_id = r.role_id WHERE r.role_name = 'Admin' LIMIT 1"
  );

  if (adminCheck.rowCount === 0) {
    await pool.query(
      "INSERT INTO user_role(user_id, role_id) SELECT $1, role_id FROM roles WHERE role_name = 'Admin'",
      [result.rows[0].user_id]
    );
  } else {
    await pool.query(
      "INSERT INTO user_role(user_id, role_id) SELECT $1, role_id FROM roles WHERE role_name = 'User'",
      [result.rows[0].user_id]
    );
  }

  return result.rows[0];
};

const deleteUser = async (userId) => {
  // Önce kullanıcıya ait rolleri sil
  await pool.query('DELETE FROM user_role WHERE user_id = $1', [userId]);
  // Sonra kullanıcıya ait tahminleri sil
  await pool.query('DELETE FROM predictions WHERE user_id = $1', [userId]);
  // En son kullanıcıyı sil
  await pool.query('DELETE FROM users WHERE user_id = $1', [userId]);
  return { success: true };
};

const getUserCount = async () => {
  const result = await pool.query('SELECT COUNT(*) as count FROM users');
  return parseInt(result.rows[0].count);
};

// Models CRUD
const getModels = async () => {
  const result = await pool.query(
    'SELECT m.*, ms.segment_name FROM models m JOIN model_segments ms ON m.segment_id = ms.segment_id ORDER BY m.model_name, ms.segment_name'
  );
  return result.rows;
};

const getModelById = async (modelId) => {
  const result = await pool.query(
    'SELECT m.*, ms.segment_name FROM models m JOIN model_segments ms ON m.segment_id = ms.segment_id WHERE m.model_id = $1',
    [modelId]
  );
  return result.rows[0];
};

const deleteModel = async (modelId) => {
  await pool.query('DELETE FROM models WHERE model_id = $1', [modelId]);
  return { success: true };
};

// Specs CRUD
const getSpecs = async () => {
  const result = await pool.query(
    `SELECT s.*, m.model_name, ms.segment_name, m.release_year, fn_specs_label(s.specs_id) as label
     FROM specs s 
     JOIN models m ON s.model_id = m.model_id 
     JOIN model_segments ms ON m.segment_id = ms.segment_id
     ORDER BY m.model_name, ms.segment_name`
  );
  return result.rows;
};

const getSpecsById = async (specsId) => {
  const result = await pool.query(
    `SELECT s.*, m.model_name, ms.segment_name, m.release_year, fn_specs_label(s.specs_id) as label
     FROM specs s 
     JOIN models m ON s.model_id = m.model_id 
     JOIN model_segments ms ON m.segment_id = ms.segment_id
     WHERE s.specs_id = $1`,
    [specsId]
  );
  return result.rows[0];
};

const deleteSpecs = async (specsId) => {
  await pool.query('DELETE FROM specs WHERE specs_id = $1', [specsId]);
  return { success: true };
};

// Predictions CRUD
const getPredictions = async () => {
  const result = await pool.query('SELECT * FROM v_prediction_history_detail ORDER BY created_at DESC');
  return result.rows;
};

const getPredictionById = async (predictionId) => {
  const result = await pool.query(
    'SELECT * FROM v_prediction_history_detail WHERE prediction_id = $1',
    [predictionId]
  );
  return result.rows[0];
};

const deletePrediction = async (predictionId) => {
  await pool.query('DELETE FROM predictions WHERE prediction_id = $1', [predictionId]);
  return { success: true };
};

const deleteCondition = async (conditionId) => {
  await pool.query('DELETE FROM device_condition WHERE condition_id = $1', [conditionId]);
  return { success: true };
};

// Roles
const getRoles = async () => {
  const result = await pool.query('SELECT * FROM roles ORDER BY role_id');
  return result.rows;
};

// Dashboard istatistikleri
const getDashboardStats = async () => {
  const stats = {};

  const userCount = await pool.query('SELECT COUNT(*) as count FROM users');
  stats.totalUsers = parseInt(userCount.rows[0].count);

  const predictionCount = await pool.query('SELECT COUNT(*) as count FROM predictions');
  stats.totalPredictions = parseInt(predictionCount.rows[0].count);

  const modelCount = await pool.query('SELECT COUNT(*) as count FROM models');
  stats.totalModels = parseInt(modelCount.rows[0].count);

  const avgPrice = await pool.query('SELECT COALESCE(AVG(predicted_price), 0) as avg FROM predictions');
  stats.avgPredictedPrice = parseFloat(avgPrice.rows[0].avg).toFixed(2);

  return stats;
};

module.exports = {
  query,
  pool,
  // Views (9 adet)
  getSpecsCatalog,
  getModelsCatalog,
  getSegmentsCatalog,
  getConditionCatalog,
  getPredictionHistoryDetail,
  getUserPredictionHistory,
  getAdminModelStats,
  getAdminConditionStats,
  getUsersMasked,
  getUserHistoryMasked,
  // Stored Procedures (8 adet)
  createPrediction,
  addSegment,
  addModel,
  addSpecs,
  updateModel,
  updateSpecs,
  addCondition,
  assignRole,
  // Functions (4 adet)
  maskEmail,
  maskUsername,
  getSpecsLabel,
  getModelSegmentName,
  // CRUD
  getUsers,
  getUserById,
  getUserByUsername,
  getAuthUserByUsername,
  createUser,
  getUserCount,
  deleteUser,
  getModels,
  getModelById,
  deleteModel,
  getSpecs,
  getSpecsById,
  deleteSpecs,
  getPredictions,
  getPredictionById,
  deletePrediction,
  getRoles,
  getDashboardStats,
  deleteCondition
};
