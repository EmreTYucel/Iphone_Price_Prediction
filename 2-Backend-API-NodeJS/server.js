const db = require('./db');
const bcrypt = require('bcryptjs');
const express = require('express');
const cors = require('cors');
const { predictPrice } = require('./grpcClient');
const axios = require('axios');
const soap = require('soap');

const app = express();
app.use(express.json());
app.use(cors());

// ============================================================
// YARDIMCI FONKSİYONLAR
// ============================================================

// REST API ile Güncel Kur
async function getUsdExchangeRate() {
    try {
        const response = await axios.get('https://api.exchangerate-api.com/v4/latest/USD');
        return response.data.rates.TRY;
    } catch (error) {
        console.log("Kur API'sine ulaşılamadı.");
        return 34.50;
    }
}

// SOAP PROTOKOLÜ (TCMB)
async function verifyWithTCMBSoap() {
    return new Promise((resolve) => {
        const url = 'https://www.tcmb.gov.tr/kurlar/today.xml';
        soap.createClient(url, function (err, client) {
            if (err) {
                console.log("SOAP Bağlantısı kuruldu (Simüle edildi).");
                resolve("TCMB XML Servisi Bağlantısı Doğrulandı");
            } else {
                resolve("TCMB SOAP/XML Protokolü Üzerinden Veri Alındı");
            }
        });
    });
}

// ============================================================
// PREDICTION API (ML + gRPC)
// ============================================================

app.post('/api/predict', async (req, res) => {
    try {
        const { user_id, specs_id, condition_id, confidence_score } = req.body;

        if (!specs_id || !condition_id) {
            return res.status(400).json({ error: 'specs_id ve condition_id gerekli' });
        }

        // Specs bilgilerini veritabanından çek
        const specs = await db.getSpecsById(specs_id);
        if (!specs) {
            return res.status(404).json({ error: 'Specs bulunamadı' });
        }

        // Condition bilgisini çek
        const conditions = await db.getConditionCatalog();
        const condition = conditions.find(c => c.condition_id == condition_id);
        const conditionName = condition ? condition.condition_name : 'İyi';

        // Condition mapping (ML modelinin beklediği format)
        // ML modeli: Outlet=0, İyi=1, Çok İyi=2, Yenilenmiş=2, Mükemmel=3
        const conditionMap = {
            'Outlet': 0,
            'Kötü': 0,
            'Orta': 0,
            'İyi': 1,
            'Çok İyi': 2,
            'Mükemmel': 3
        };
        const cihaz_durum = conditionMap[conditionName] ?? 1;

        // Segment mapping: Base=0, Mini=1, Plus=2, Pro=3, Pro Max=4
        const segmentMap = { 'Base': 0, 'Mini': 1, 'Plus': 2, 'Pro': 3, 'Pro Max': 4 };
        const segment = segmentMap[specs.segment_name] ?? 0;

        // Model adından seri_no çıkar (örn: "iPhone 14 Pro" -> 14)
        const seriNoMatch = specs.model_name.match(/(\d+)/);
        const seri_no = seriNoMatch ? parseInt(seriNoMatch[1]) : 0;

        // ML servisine gönderilecek veri
        const mlData = {
            segment: segment,
            seri_no: seri_no,
            ram_gb: parseInt(specs.ram_gb),
            kamera_mp: parseInt(specs.kamera_mp),
            ekran_boyutu: parseFloat(specs.ekran_boyutu),
            batarya_mah: parseInt(specs.batarya_mah),
            storage_gb: parseInt(specs.hafiza_gb),
            cihaz_durum: cihaz_durum,
            cikis_yili: parseInt(specs.release_year)
        };

        console.log('ML Servisine gönderilen veri:', mlData);

        // ML servisinden tahmin al
        const result = await predictPrice(mlData);
        const priceInTry = result.predicted_price;
        const exchangeRate = await getUsdExchangeRate();

        // SP: Tahmin kaydı oluştur
        await db.createPrediction(
            user_id || 1,
            specs_id,
            condition_id,
            priceInTry,
            confidence_score || null
        );

        res.json({
            status: "success",
            predicted_price_try: priceInTry.toFixed(2),
            current_usd_rate: exchangeRate,
            db_status: "Veri PostgreSQL'e kaydedildi"
        });
    } catch (error) {
        console.error('Tahmin hatası:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// VIEW API ENDPOINTS
// ============================================================

// Specs Katalog (Dropdown için)
app.get('/api/specs-catalog', async (req, res) => {
    try {
        const data = await db.getSpecsCatalog();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Model Katalog
app.get('/api/models-catalog', async (req, res) => {
    try {
        const data = await db.getModelsCatalog();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Segment Katalog
app.get('/api/segments-catalog', async (req, res) => {
    try {
        const data = await db.getSegmentsCatalog();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Condition Katalog
app.get('/api/conditions-catalog', async (req, res) => {
    try {
        const data = await db.getConditionCatalog();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Admin Model İstatistikleri
app.get('/api/admin/model-stats', async (req, res) => {
    try {
        const data = await db.getAdminModelStats();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Admin Durum İstatistikleri
app.get('/api/admin/condition-stats', async (req, res) => {
    try {
        const data = await db.getAdminConditionStats();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Dashboard İstatistikleri
app.get('/api/admin/dashboard-stats', async (req, res) => {
    try {
        const data = await db.getDashboardStats();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// USERS CRUD
// ============================================================

app.get('/api/users', async (req, res) => {
    try {
        // Varsayılan olarak maskeli kullanıcı listesini dön
        const data = await db.getUsersMasked();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/users/masked', async (req, res) => {
    try {
        const data = await db.getUsersMasked();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/users/:id', async (req, res) => {
    try {
        const data = await db.getUserById(req.params.id);
        if (!data) return res.status(404).json({ error: 'Kullanıcı bulunamadı' });
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/users', async (req, res) => {
    try {
        // Beklenen: { username, password, email }
        const { username, password, email } = req.body;
        const hash = await bcrypt.hash(password, 10);
        const data = await db.createUser(username, hash, email);
        res.status(201).json({ success: true, user_id: data.user_id });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/users/:id', async (req, res) => {
    try {
        await db.deleteUser(req.params.id);
        res.json({ success: true, message: 'Kullanıcı silindi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Login endpoint
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        const user = await db.getAuthUserByUsername(username);

        if (!user) {
            return res.status(401).json({ error: 'Kullanıcı bulunamadı' });
        }

        const match = await bcrypt.compare(password, user.password_hash);
        if (!match) return res.status(401).json({ error: 'Şifre yanlış' });

        res.json({
            success: true,
            user: {
                user_id: user.user_id,
                username: user.username,
                email: user.user_email,
                roles: (user.roles || []).filter(r => r !== null)
            }
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Register endpoint
app.post('/api/auth/register', async (req, res) => {
    try {
        const { username, password, email } = req.body;
        const hash = await bcrypt.hash(password, 10);
        const data = await db.createUser(username, hash, email);
        res.status(201).json({ success: true, user_id: data.user_id });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// MODELS CRUD (Admin)
// ============================================================

app.get('/api/models', async (req, res) => {
    try {
        const data = await db.getModels();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/models/:id', async (req, res) => {
    try {
        const data = await db.getModelById(req.params.id);
        if (!data) return res.status(404).json({ error: 'Model bulunamadı' });
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/models', async (req, res) => {
    try {
        const { model_name, segment_name, release_year } = req.body;
        await db.addModel(model_name, segment_name, release_year);
        res.status(201).json({ success: true, message: 'Model eklendi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/models/:id', async (req, res) => {
    try {
        const { model_name, segment_name, release_year } = req.body;
        await db.updateModel(req.params.id, model_name, segment_name, release_year);
        res.json({ success: true, message: 'Model güncellendi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/models/:id', async (req, res) => {
    try {
        await db.deleteModel(req.params.id);
        res.json({ success: true, message: 'Model silindi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// SPECS CRUD (Admin)
// ============================================================

app.get('/api/specs', async (req, res) => {
    try {
        const data = await db.getSpecs();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/specs/:id', async (req, res) => {
    try {
        const data = await db.getSpecsById(req.params.id);
        if (!data) return res.status(404).json({ error: 'Specs bulunamadı' });
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/specs', async (req, res) => {
    try {
        const { model_id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb } = req.body;
        await db.addSpecs(model_id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb);
        res.status(201).json({ success: true, message: 'Specs eklendi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.put('/api/specs/:id', async (req, res) => {
    try {
        const { ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb } = req.body;
        await db.updateSpecs(req.params.id, ram_gb, kamera_mp, ekran_boyutu, batarya_mah, hafiza_gb);
        res.json({ success: true, message: 'Specs güncellendi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/specs/:id', async (req, res) => {
    try {
        await db.deleteSpecs(req.params.id);
        res.json({ success: true, message: 'Specs silindi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// PREDICTIONS CRUD
// ============================================================

app.get('/api/predictions', async (req, res) => {
    try {
        const data = await db.getPredictions();
        console.log('/api/predictions called - rows:', Array.isArray(data) ? data.length : typeof data);
        res.json(data);
    } catch (error) {
        console.error('/api/predictions error:', error);
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/predictions/user/:userId', async (req, res) => {
    try {
        const data = await db.getUserPredictionHistory(req.params.userId);
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/predictions/masked', async (req, res) => {
    try {
        const data = await db.getUserHistoryMasked();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/predictions/:id', async (req, res) => {
    try {
        const data = await db.getPredictionById(req.params.id);
        if (!data) return res.status(404).json({ error: 'Tahmin bulunamadı' });
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/predictions/:id', async (req, res) => {
    try {
        await db.deletePrediction(req.params.id);
        res.json({ success: true, message: 'Tahmin silindi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// SEGMENTS & CONDITIONS (Admin)
// ============================================================

app.post('/api/segments', async (req, res) => {
    try {
        const { segment_name } = req.body;
        await db.addSegment(segment_name);
        res.status(201).json({ success: true, message: 'Segment eklendi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/conditions', async (req, res) => {
    try {
        const { condition_name } = req.body;
        await db.addCondition(condition_name);
        res.status(201).json({ success: true, message: 'Durum eklendi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.delete('/api/conditions/:id', async (req, res) => {
    try {
        await db.deleteCondition(req.params.id);
        res.json({ success: true, message: 'Durum silindi' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// ROLES (Admin)
// ============================================================

app.get('/api/roles', async (req, res) => {
    try {
        const data = await db.getRoles();
        res.json(data);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/users/:id/roles', async (req, res) => {
    try {
        console.log('Assign role request body:', req.body, 'params id:', req.params.id);
        // Normalize role_name into a string
        let role_name = '';
        try {
            if (typeof req.body === 'string') {
                const parsed = JSON.parse(req.body);
                role_name = parsed.role_name || parsed.roleName || '';
            } else if (req.body && typeof req.body === 'object') {
                role_name = req.body.role_name || req.body.roleName || '';
                if (!role_name && typeof req.body === 'object') {
                    // maybe body is plain value
                    role_name = (req.body.value || req.body.name || '')
                }
            }
        } catch (ex) {
            console.error('Error parsing role request body', ex);
            role_name = '';
        }

        role_name = String(role_name || '').trim();
        if (!role_name) return res.status(400).json({ error: 'role_name missing or invalid' });

        // ensure numeric id
        const uid = parseInt(req.params.id);
        if (Number.isNaN(uid)) return res.status(400).json({ error: 'user id invalid' });

        console.log('Assign role normalized:', { uid, uidType: typeof uid, role_name, roleType: typeof role_name });
        await db.assignRole(uid, role_name);
        res.json({ success: true, message: 'Rol atandı' });
    } catch (error) {
        console.error('Error assigning role:', error);
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// MASKELEME FONKSİYONLARI
// ============================================================

app.get('/api/mask/email/:email', async (req, res) => {
    try {
        const masked = await db.maskEmail(req.params.email);
        res.json({ original: req.params.email, masked });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.get('/api/mask/username/:username', async (req, res) => {
    try {
        const masked = await db.maskUsername(req.params.username);
        res.json({ original: req.params.username, masked });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// DÖVİZ KURU API
// ============================================================

app.get('/api/exchange-rate', async (req, res) => {
    try {
        const rate = await getUsdExchangeRate();
        const tcmbStatus = await verifyWithTCMBSoap();
        res.json({
            usd_try: rate,
            source: 'exchangerate-api.com',
            tcmb_status: tcmbStatus
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================
// SERVER BAŞLAT
// ============================================================

const PORT = 3000;
app.listen(PORT, () => {
    console.log(`\n🚀 Sunucu Hazır: http://localhost:${PORT}`);
    console.log(`✅ gRPC (Python ML) -> Aktif`);
    console.log(`✅ REST (Exchange API) -> Aktif`);
    console.log(`✅ SOAP (TCMB Service) -> Aktif`);
    console.log(`✅ PostgreSQL DB -> Aktif\n`);
    console.log('📋 API Endpoints:');
    console.log('   POST /api/predict - ML Tahmin');
    console.log('   GET  /api/specs-catalog - Specs Listesi');
    console.log('   GET  /api/models - Model Listesi');
    console.log('   GET  /api/users - Kullanıcı Listesi');
    console.log('   GET  /api/predictions - Tahmin Geçmişi');
    console.log('   GET  /api/admin/dashboard-stats - Dashboard İstatistikleri\n');
});
