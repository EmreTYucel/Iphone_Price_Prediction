using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace _3_Web_UI_ASPNET.Controllers
{
    public class PredictionController : Controller
    {
        private readonly HttpClient _httpClient;
        private const string API_BASE_URL = "http://localhost:3000";

        public PredictionController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new System.Uri(API_BASE_URL);
        }

        // Tahmin Girişi Formu (GET)
        [HttpGet]
        public IActionResult Create()
        {
            // Giriş kontrolü
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
            {
                return RedirectToAction("Login", "Account");
            }

            ViewBag.UserRole = HttpContext.Session.GetString("role") ?? "";
            ViewBag.IsLoggedIn = true;
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            return View();
        }

        // Tahmin Hesapla (POST)
        [HttpPost]
        public async Task<IActionResult> Create(int specs_id, int condition_id)
        {
            try
            {
                var userId = HttpContext.Session.GetString("user_id") ?? "1";
                var predictData = new
                {
                    user_id = int.Parse(userId),
                    specs_id = specs_id,
                    condition_id = condition_id
                };

                var json = JsonSerializer.Serialize(predictData);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/api/predict", content);
                var responseContent = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode)
                {
                    var result = JsonSerializer.Deserialize<JsonElement>(responseContent);
                    
                    // predicted_price_try string olarak geliyor
                    var priceElement = result.GetProperty("predicted_price_try");
                    var price = priceElement.ValueKind == JsonValueKind.String 
                        ? priceElement.GetString() 
                        : priceElement.GetDouble().ToString("F2");
                    
                    // current_usd_rate number olabilir
                    var rateElement = result.GetProperty("current_usd_rate");
                    var rate = rateElement.ValueKind == JsonValueKind.Number 
                        ? rateElement.GetDouble().ToString("F2") 
                        : rateElement.GetString();
                    
                    TempData["PredictedPrice"] = price;
                    TempData["UsdRate"] = rate;
                    TempData["SpecsId"] = specs_id.ToString();
                    TempData["ConditionId"] = condition_id.ToString();
                    return RedirectToAction("Result");
                }
                else
                {
                    TempData["ErrorMessage"] = "Tahmin yapılırken hata oluştu.";
                }
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "API bağlantı hatası: " + ex.Message;
            }
            return RedirectToAction("Create");
        }

        // Tahmin Sonucu Göster (TempData kullanımı)
        public IActionResult Result()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
            {
                return RedirectToAction("Login", "Account");
            }

            ViewBag.UserRole = HttpContext.Session.GetString("role") ?? "";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            return View();
        }
    }
}
