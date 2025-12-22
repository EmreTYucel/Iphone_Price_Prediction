import csv
import time
import re # Düzenli ifadeler (Regex) kütüphanesi, fiyatı temizlemek için
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from webdriver_manager.chrome import ChromeDriverManager

# --- YARDIMCI 1: Fiyatı Temizleyip İnt Yapma ---
def fiyati_temizle(fiyat_metni):
    
    try:
        # 1. "TL" ve boşlukları sil
        temiz = fiyat_metni.replace("TL", "").replace("tl", "").strip()
        
        # 2. Virgülden sonrasını (kuruş) at
        if "," in temiz:
            temiz = temiz.split(",")[0]
            
        # 3. Noktaları (binlik ayıracı) sil -> "119.999" olur "119999"
        temiz = temiz.replace(".", "")
        
        # 4. Geriye kalan sadece sayı mı? İnt'e çevir.
        if temiz.isdigit():
            return int(temiz)
        else:
            return 0 # Sayıya çevrilemezse 0 döner
    except:
        return 0

# --- YARDIMCI 2: Butona Tıklama ---
def butona_tikla(driver, buton_class):
    print("2. Sayfa sonuna iniliyor...")
    driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
    time.sleep(2)
    try:
        buton_selector = f".{buton_class}"
        buton = WebDriverWait(driver, 5).until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, buton_selector))
        )
        driver.execute_script("arguments[0].click();", buton)
        print(">>> BUTONA 1 KEZ TIKLANDI. Yükleniyor...")
        time.sleep(6)
    except Exception:
        print("Bilgi: Buton bulunamadı (Liste tam açık olabilir).")

# --- YARDIMCI 3: Karttan Veri Çıkarma ---
def karttan_veri_al(kart, isim_class, fiyat_class):
    # Scroll ile odaklan
    driver = kart.parent
    driver.execute_script("arguments[0].scrollIntoView({behavior: 'smooth', block: 'center'});", kart)
    
    # --- İSİM BULMA (ZTKTN) ---
    isim = "İsim Yok"
    try:
        # Öncelik senin verdiğin sınıf
        isim = kart.find_element(By.CLASS_NAME, isim_class).text.strip()
    except:
        # Bulamazsa yedeğe geç (h3)
        try:
            isim = kart.find_element(By.TAG_NAME, "h3").text.strip()
        except:
            pass

    # --- FİYAT BULMA (rTdMX) ---
    ham_fiyat = "0"
    try:
        # Öncelik senin verdiğin sınıf
        ham_fiyat = kart.find_element(By.CLASS_NAME, fiyat_class).text
    except:
        # Bulamazsa metin analizi yap
        try:
            satirlar = kart.text.split('\n')
            for s in satirlar:
                if "TL" in s:
                    ham_fiyat = s
                    break
        except:
            pass
            
    # Fiyatı temizle ve sayıya çevir
    temiz_fiyat = fiyati_temizle(ham_fiyat)

    return isim, temiz_fiyat

# --- ANA FONKSİYON ---
def veri_botu_final():
    HEDEF_URL = "https://www.cimri.com/yenilenmis-cep-telefonlari/en-ucuz-apple-iphone-11-64gb-4gb-ram-yenilenmis-cep-telefonu-fiyatlari,a2197563979"
    DOSYA_ADI = "CIMRI_yenilenmiş_V67.csv"
    
    # SENİN BELİRLEDİĞİN SINIFLAR
    KART_SELECTOR = "div[data-offer]" # Kartları bulmak için en garantisi bu
    ISIM_CLASS = "ZTKTN"
    FIYAT_CLASS = "rTdMX"
    BUTON_CLASS = "cimri-icon-arrow-down-cheapest"
    
    # Yasaklı Kelimeler (Reklamları elemek için)
    YASAKLI = ["REKLAM", "EN UCUZ"]

    options = webdriver.ChromeOptions()
    options.add_argument("--start-maximized")
    options.add_argument("--log-level=3") 
    driver = webdriver.Chrome(service=Service(ChromeDriverManager().install()), options=options)
    
    tum_veriler = []

    try:
        print("1. Siteye gidiliyor...")
        driver.get(HEDEF_URL)
        time.sleep(5) 

        # ADIM 1: Tıkla
        butona_tikla(driver, BUTON_CLASS)

        # ADIM 2: Topla
        print("3. Veriler toplanıyor...")
        driver.execute_script("window.scrollTo(0, 0);")
        time.sleep(2)

        kartlar = driver.find_elements(By.CSS_SELECTOR, KART_SELECTOR)
        print(f"   -> Toplam {len(kartlar)} kart bulundu.")

        for kart in kartlar:
            try:
                isim, fiyat_int = karttan_veri_al(kart, ISIM_CLASS, FIYAT_CLASS)
                data_id = kart.get_attribute("data-offer") or "yok"

                # Filtreleme: İsim yasaklı kelime içeriyorsa veya fiyat 0 ise alma
                if isim == "İsim Yok" or any(y in isim for y in YASAKLI):
                    continue
                
                # Listeye ekle
                tum_veriler.append([data_id, isim, fiyat_int])
                print(f"   + {isim[:30]}... -> {fiyat_int}")
                
            except Exception:
                continue

        # ADIM 3: Kaydet
        print(f"\nToplam {len(tum_veriler)} veri kaydediliyor...")
        with open(DOSYA_ADI, mode='w', newline='', encoding='utf-8-sig') as file:
            writer = csv.writer(file)
            writer.writerow(['ID', 'Urun Ismi', 'Fiyat (Int)'])
            writer.writerows(tum_veriler)
            
        print(f"Dosya hazır: {DOSYA_ADI}")

    except Exception as hata:
        print(f"Hata: {hata}")
    finally:
        driver.quit()

if __name__ == "__main__":
    veri_botu_final()