import csv
import time
import re
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

def easycep_final_scraper_v2():
    # --- AYARLAR ---
    BASLANGIC_SAYFA = 1
    BITIS_SAYFA = 2
    
    # Yasaklı kelimeler (Durum bilgileri isim değildir)
    YASAKLI_KELIMELER = ["Mükemmel", "Çok İyi", "İyi", "Outlet", "Sıfır Gibi", "Tükenmek Üzere", "Kampanyalı"]

    # Tarayıcı Ayarları
    options = webdriver.ChromeOptions()
    options.add_argument("--start-maximized")
    
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    tum_veriler = [] 

    try:
        # --- SAYFA DÖNGÜSÜ ---
        for sayfa_no in range(BASLANGIC_SAYFA, BITIS_SAYFA):
            url = f"https://easycep.com/kategori/apple-2?sortingCriteria=1&page={sayfa_no}"
            print(f"\n🌍 [{sayfa_no}. Sayfa] Siteye bağlanılıyor...")
            
            try:
                driver.get(url)
                WebDriverWait(driver, 20).until(EC.presence_of_element_located((By.TAG_NAME, "body")))
                
                # Scroll
                for i in range(1, 30):
                    driver.execute_script(f"window.scrollTo(0, {i * 700});")
                    time.sleep(0.5)

                # Kartları bul
                XPATH_KARTLAR = '//*[@id="easycep-root"]/div[1]/main/div/div/div[2]/div/div[2]/div/div'
                XPATH_FIYAT_RELATIVE = './div/div[2]/div[2]/div/span'

                kartlar = driver.find_elements(By.XPATH, XPATH_KARTLAR)
                print(f"   📦 Kart sayısı: {len(kartlar)}")

                for kart in kartlar:
                    try:
                        # 1. FİYAT ÇEKME
                        temiz_fiyat = 0.0
                        try:
                            fiyat_elementi = kart.find_element(By.XPATH, XPATH_FIYAT_RELATIVE)
                            raw_fiyat = fiyat_elementi.text.strip()
                            if "TL" in raw_fiyat:
                                temiz_fiyat = float(raw_fiyat.replace("TL", "").replace(".", "").replace(",", ".").strip())
                        except:
                            continue 
                        
                        if temiz_fiyat == 0.0: continue

                        # 2. İSİM ve ÖZELLİK ÇEKME (GÜNCELLENDİ)
                        kart_text = kart.text
                        lines = kart_text.split('\n')
                        
                        cihaz_isim = "Bulunamadı"
                        cihaz_pil = "Belirtilmemiş"
                        cihaz_durum = "Belirtilmemiş"

                        # --- YENİ İSİM BULMA MANTIĞI ---
                        # Hedef: Sadece "Apple" yazanı değil, "iPhone ... GB" yazan uzun satırı bulmak.
                        for line in lines:
                            line = line.strip()
                            
                            # Gereksiz satırları atla
                            if line in YASAKLI_KELIMELER or "TL" in line or "%" in line:
                                continue
                            
                            # KURAL: İçinde "iPhone" geçiyorsa VE satır uzunluğu 10 karakterden fazlaysa
                            # (Böylece sadece "Apple" veya sadece "iPhone" yazan kısa satırları almaz)
                            if "iPhone" in line and len(line) > 10:
                                cihaz_isim = line
                                break # En uzun ve doğru ismi bulduk, döngüden çık
                            
                        # Eğer yukarıdaki yöntemle bulamadıysa (örn: iPhone yazmıyorsa), 
                        # içinde GB geçen satırı bul (Telefon isimlerinde genelde GB yazar)
                        if cihaz_isim == "Bulunamadı":
                            for line in lines:
                                if "GB" in line and "TL" not in line:
                                    cihaz_isim = line
                                    break

                        # B) Pil Sağlığı
                        match_pil = re.search(r'%[\d-]+', kart_text)
                        if match_pil:
                            cihaz_pil = match_pil.group(0)

                        # C) Kozmetik Durum
                        for d in YASAKLI_KELIMELER:
                            if d in kart_text:
                                cihaz_durum = d
                                break

                        tum_veriler.append({
                            "cihaz_isim": cihaz_isim,
                            "cihaz_durum": cihaz_durum,
                            "cihaz_pil": cihaz_pil,
                            "cihaz_fiyat": temiz_fiyat,
                            "kaynak_sayfa": sayfa_no
                        })

                    except Exception as e:
                        continue 
                
                print(f"   ✅ Veri toplandı. (Toplam: {len(tum_veriler)})")

            except Exception as e:
                print(f"   !!! Sayfa hatası: {e}")
                continue

    except Exception as e:
        print(f"Genel Hata: {e}")

    finally:
        driver.quit()
        if tum_veriler:
            dosya_adi = "easycepApple_v1.csv"
            with open(dosya_adi, 'w', newline='', encoding='utf-8-sig') as f:
                writer = csv.DictWriter(f, fieldnames=["cihaz_isim", "cihaz_durum", "cihaz_pil", "cihaz_fiyat", "kaynak_sayfa"])
                writer.writeheader()
                writer.writerows(tum_veriler)
            print(f"\n🎉 Dosya oluşturuldu: {dosya_adi}")

if __name__ == "__main__":
    easycep_final_scraper_v2()