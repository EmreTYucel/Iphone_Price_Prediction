import time
import pandas as pd
import uuid
import datetime
import random
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager
from bs4 import BeautifulSoup

# --- AYARLAR VE MAPPING ---
MODEL_YIL_MAP = {
    "iPhone 16": 2024, "iPhone 15": 2023, "iPhone 14": 2022,
    "iPhone 13": 2021, "iPhone 12": 2020, "iPhone 11": 2019,
    "iPhone XS": 2018, "iPhone XR": 2018, "iPhone X": 2017
}

def get_teknoloji_yasi(cikis_yili):
    if cikis_yili == "Bilinmiyor": return "Bilinmiyor"
    return datetime.datetime.now().year - cikis_yili

def model_yili_bul(cihaz_isim):
    for model, yil in MODEL_YIL_MAP.items():
        if model in cihaz_isim: return yil
    return "Bilinmiyor"

# --- TARAYICI AYARLARI ---
options = webdriver.ChromeOptions()
options.add_argument("--disable-notifications")
options.add_argument("--start-maximized")
# options.add_argument("--headless") # Arka planda çalışsın istersen yorum satırını kaldır

driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
wait = WebDriverWait(driver, 15) # Elementlerin yüklenmesi için 15 sn bekleme süresi

base_url = "https://getmobil.com/satin-al/cep-telefonu/android-telefonlar/xiaomi/redmi-note-12-pro-5g/"
tum_veri_listesi = []

try:
    # 1'den n. sayfaya kadar gez
    for page_num in range(1, 3):
        target_url = f"{base_url}?pageNumber={page_num}"
        print(f"\n--- Sayfa {page_num} işleniyor: {target_url} ---")
        
        driver.get(target_url)
        
        try:
            # Kritik Nokta: Senin verdiğin HTML'deki 'product-grid-card' sınıfının yüklenmesini bekle
            wait.until(EC.presence_of_element_located((By.CLASS_NAME, "product-grid-card")))
            
            # Sayfa tam yüklendiğinde HTML'i çekip BeautifulSoup'a veriyoruz
            soup = BeautifulSoup(driver.page_source, "html.parser")
            
            # Senin verdiğin ana kapsayıcı class: 'product-grid-card'
            kartlar = soup.find_all("a", class_="product-grid-card")
            print(f"-> {len(kartlar)} adet ürün kartı bulundu.")
            
            for kart in kartlar:
                try:
                    # 1. CİHAZ İSMİ
                    # HTML Örneği: <h3 class="product-grid-card__offer-title" ...>
                    isim_tag = kart.find("h3", class_="product-grid-card__offer-title")
                    cihaz_isim = isim_tag.text.strip() if isim_tag else "Bilinmiyor"
                    
                    # 2. FİYAT
                    # HTML Örneği: data-testid="product-grid-card-1-price-text"
                    # data-testid her kartta değiştiği için (card-1, card-2) sonu 'price-text' ile biteni buluyoruz
                    fiyat_tag = kart.find(attrs={"data-testid": lambda x: x and x.endswith("price-text")})
                    raw_fiyat = fiyat_tag.text.strip() if fiyat_tag else "0"
                    cihaz_fiyat = raw_fiyat.replace("₺", "").replace(".", "").strip()
                    
                    # 3. DURUM (Mükemmel, Çok İyi vs.)
                    # HTML Örneği: data-testid="product-grid-card-1-condition"
                    durum_tag = kart.find("p", attrs={"data-testid": lambda x: x and x.endswith("condition")})
                    cihaz_durum = durum_tag.text.strip() if durum_tag else "Bilinmiyor"
                    
                    # 4. KAPASİTE (RAM sütunu için)
                    # HTML Örneği: data-testid="product-grid-card-1-attribute-1" -> "256 GB"
                    kapasite_tag = kart.find("p", attrs={"data-testid": lambda x: x and x.endswith("attribute-1")})
                    kapasite = kapasite_tag.text.strip() if kapasite_tag else "Bilinmiyor"

                    # 5. OTO GENERATE EDİLEN ALANLAR
                    row_id = uuid.uuid4().hex[:8]
                    cikis_yili = model_yili_bul(cihaz_isim)
                    teknoloji_yasi = get_teknoloji_yasi(cikis_yili)
                    seri_no = f"GM-{uuid.uuid4().hex[:6].upper()}"
                    
                    tum_veri_listesi.append({
                        "id": row_id,
                        "cihaz_isim": cihaz_isim,
                        "cihaz_durum": cihaz_durum,
                        "cihaz_pil": "Standart %85+",
                        "cihaz_fiyat": cihaz_fiyat,
                        "kaynak_sayfa": target_url,
                        "seri_no": seri_no,
                        "ram_gb": kapasite,
                        "cikis_yili": cikis_yili,
                        "teknoloji_yasi": teknoloji_yasi
                    })
                    
                except Exception as e:
                    print(f"Kart okuma hatası: {e}")
                    continue
            
            # Sayfa geçişinde insan gibi bekle
            time.sleep(random.uniform(2, 4))
            
        except Exception as e:
            print(f"Sayfa {page_num} yüklenemedi veya zaman aşımı: {e}")

except Exception as e:
    print(f"Genel Hata: {e}")

finally:
    driver.quit()
    
    # --- KAYDETME ---
    if tum_veri_listesi:
        df = pd.DataFrame(tum_veri_listesi)
        df.to_csv("redmi-note-12-pro-5g.csv", index=False, encoding="utf-8-sig")
        print(f"\nİŞLEM BAŞARILI! Toplam {len(tum_veri_listesi)} satır veri 'getmobil_final_data.csv' dosyasına kaydedildi.")
        print(df.head())
    else:
        print("\nVeri çekilemedi. HTML yapısı değişmiş olabilir.")