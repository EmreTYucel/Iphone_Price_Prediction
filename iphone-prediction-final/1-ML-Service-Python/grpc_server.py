import grpc
from concurrent import futures
import joblib
import numpy as np
import os
import sys

# Terminal çıktılarını anında görmek için flush kullanıyoruz
def log(msg):
    print(f">>> {msg}", flush=True)

log("Servis baslatma prosedürü devreye girdi...")

try:
    # Yol ayarları
    current_dir = os.path.dirname(os.path.abspath(__file__))
    sys.path.append(current_dir)
    
    import prediction_pb2
    import prediction_pb2_grpc
    log("Proto dosyalari basariyla yüklendi.")

    # Model yükleme
    model_path = os.path.join(current_dir, 'models', 'Gradient_model.pkl')
    if not os.path.exists(model_path):
        log(f"KRITIK HATA: Model dosyasi bulunamadi! Yol: {model_path}")
        sys.exit(1)
        
    model = joblib.load(model_path)
    log("Makine ögrenmesi modeli (Gradient Boosting) bellege alindi.")

    class PricePredictorServicer(prediction_pb2_grpc.PricePredictorServicer):
        def PredictPrice(self, request, context):
            log(f"Yeni tahmin istegi alindi: Segment {request.segment}")
            input_data = np.array([[
                request.segment, request.seri_no, request.ram_gb, 
                request.kamera_mp, request.ekran_boyutu, request.batarya_mah, 
                request.storage_gb, request.cihaz_durum, request.cikis_yili
            ]])
            prediction = model.predict(input_data)[0]
            return prediction_pb2.PredictionResponse(predicted_price=float(prediction))

    def serve():
        server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
        prediction_pb2_grpc.add_PricePredictorServicer_to_server(PricePredictorServicer(), server)
        server.add_insecure_port('[::]:50051')
        log("SUNUCU HAZIR: 50051 portu üzerinden dinleniyor...")
        server.start()
        server.wait_for_termination()

    if __name__ == '__main__':
        serve()

except Exception as e:
    log(f"BEKLENMEDIK HATA: {str(e)}")