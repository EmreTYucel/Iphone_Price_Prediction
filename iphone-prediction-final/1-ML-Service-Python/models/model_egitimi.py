import pandas as pd
from sklearn.ensemble import GradientBoostingRegressor
import joblib

# 1. Veri Setinin Yüklenmesi
df = pd.read_csv(r'C:\python calismalar\mlveri_duzenleme\iphone_final_cleaned_dataset.csv')

# 2. Özelliklerin (X) ve Hedef Değişkenin (y) Belirlenmesi
# Hedef değişken: cihaz_fiyat 
X = df.drop(columns=['cihaz_fiyat'])
y = df['cihaz_fiyat']

# 3. Gradient Boosting Regressor Modelinin Kurulması
# Bu model, hata oranını her adımda minimize ederek yüksek tahmin başarısı sağlar.
model = GradientBoostingRegressor(
    n_estimators=100, 
    learning_rate=0.1, 
    max_depth=3, 
    random_state=42
)

# 4. Modelin Eğitilmesi
model.fit(X, y)

# 5. Modelin .pkl Olarak Kaydedilmesi
# Proje yapısına göre: 1-ML-Service-Python/models/model.pkl 
joblib.dump(model, 'model.pkl')

print("Gradient Boosting modeli başarıyla eğitildi ve 'model.pkl' olarak kaydedildi.")