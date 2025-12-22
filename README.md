# 📱 iPhone Fiyat Tahmin Sistemi

<div align="center">

**Makine öğrenmesi tabanlı, katmanlı mimari ile geliştirilmiş iPhone fiyat tahmin web uygulaması**

[![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)](https://python.org)
[![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![ASP.NET](https://img.shields.io/badge/ASP.NET-512BD4?style=for-the-badge&logo=dotnet&logoColor=white)](https://dotnet.microsoft.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)](https://postgresql.org)

</div>

---

## 🎯 Proje Hakkında

Bu proje, kullanıcıların iPhone özelliklerini girerek tahmini piyasa fiyatını öğrenmelerini sağlayan bir web uygulamasıdır. Sistem, **Gradient Boosting** algoritması kullanarak eğitilmiş bir makine öğrenmesi modeli ile çalışmaktadır.

---

## 🏗️ Mimari Yapı

```
┌─────────────────────────────────────────────────────────────────┐
│                    3-Web-UI-ASPNET (MVC)                        │
│                    Kullanıcı Arayüzü                            │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP
┌────────────────────────────▼────────────────────────────────────┐
│                 2-Backend-API-NodeJS                            │
│            REST API + SOAP (Döviz Kuru)                         │
└──────────┬─────────────────────────────────────┬────────────────┘
           │ gRPC                                │ SQL
┌──────────▼──────────┐              ┌───────────▼────────────────┐
│ 1-ML-Service-Python │              │    4-Database-SQL          │
│  Tahmin Modeli      │              │     PostgreSQL             │
└─────────────────────┘              └────────────────────────────┘
```

---

## 📂 Proje Yapısı

| Klasör | Açıklama | Teknolojiler |
|--------|----------|--------------|
| **1-ML-Service-Python** | Makine öğrenmesi modeli ve gRPC sunucusu | Python, Scikit-learn, gRPC |
| **2-Backend-API-NodeJS** | REST/SOAP API ve iş mantığı katmanı | Node.js, Express, gRPC Client |
| **3-Web-UI-ASPNET** | Kullanıcı arayüzü (MVC pattern) | ASP.NET Core 9.0, Razor, Bootstrap |
| **4-Database-SQL** | Veritabanı şemaları ve prosedürler | PostgreSQL |

---

## ✨ Özellikler

### 🤖 Makine Öğrenmesi
- Gradient Boosting Regressor ile fiyat tahmini
- Web scraping ile toplanan gerçek veriler
- Detaylı EDA (Exploratory Data Analysis)

### 🔌 Servis Odaklı Mimari (SOA)
- gRPC ile Python-Node.js iletişimi
- TCMB SOAP servisi ile güncel döviz kurları
- RESTful API tasarımı

### 🔐 Güvenlik
- Role-Based Access Control (Admin/User)
- Dinamik veri maskeleme (GDPR uyumlu)
- Şifreli kullanıcı bilgileri (bcrypt)

### 🎨 Kullanıcı Arayüzü
- Responsive tasarım (Bootstrap)
- Admin paneli
- Tahmin geçmişi görüntüleme
- Sistem logları

---

## 🗄️ Veritabanı

### Tablolar
| Tablo | Açıklama |
|-------|----------|
| Users | Kullanıcı hesapları |
| Predictions | Tahmin kayıtları |
| SystemLogs | Sistem aktivite logları |

### Veritabanı Nesneleri
- ✅ Stored Procedures (Tahmin kaydetme, kullanıcı işlemleri)
- ✅ Views (Raporlama, maskeli veriler)
- ✅ Functions (Veri maskeleme, etiketleme)

---

## 👥 Kullanıcı Rolleri

| Rol | Yetkiler |
|-----|----------|
| 👤 **User** | Tahmin yapma, kendi geçmişini görüntüleme |
| 👑 **Admin** | Tüm işlemler, model güncelleme, kullanıcı yönetimi, sistem logları |

---

## 🛠️ Kullanılan Teknolojiler

<div align="center">

| Katman | Teknoloji Stack |
|--------|-----------------|
| **Frontend** | ASP.NET Core MVC, Razor Views, Bootstrap 5, jQuery |
| **Backend** | Node.js, Express.js, gRPC, SOAP |
| **ML Servisi** | Python, Scikit-learn, Pandas, NumPy |
| **Veritabanı** | PostgreSQL |
| **Veri Toplama** | BeautifulSoup, Selenium |

</div>

---

## 📊 Model Bilgileri

- **Algoritma:** Gradient Boosting Regressor
- **Veri Kaynağı:** Cimri, Getmobil (Web Scraping)
- **Özellikler:** Model, Depolama, RAM, Renk, Durum vb.

---

## 📝 Lisans

Bu proje eğitim amaçlı geliştirilmiştir.

---
