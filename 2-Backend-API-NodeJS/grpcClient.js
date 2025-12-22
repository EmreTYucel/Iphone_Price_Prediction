const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const path = require('path');

// 1. Proto dosyasının yolunu belirliyoruz
// Yanlış olan: const PROTO_PATH = path.join(__current_dir, 'proto', 'prediction.proto');
// Doğru olan:
const PROTO_PATH = path.join(__dirname, 'proto', 'prediction.proto');

// 2. Proto dosyasını yüklüyoruz
const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true
});

const predictionProto = grpc.loadPackageDefinition(packageDefinition);

// 3. Python sunucusuna bağlanacak istemciyi oluşturuyoruz
// Python sunucumuz 50051 portunda çalıştığı için buraya da aynısını yazıyoruz
const client = new predictionProto.PricePredictor(
    'localhost:50051',
    grpc.credentials.createInsecure()
);

// 4. Tahmin yapacak fonksiyonu dışarıya ihraç ediyoruz
const predictPrice = (phoneData) => {
    return new Promise((resolve, reject) => {
        client.PredictPrice(phoneData, (error, response) => {
            if (!error) {
                resolve(response);
            } else {
                reject(error);
            }
        });
    });
};

module.exports = { predictPrice };