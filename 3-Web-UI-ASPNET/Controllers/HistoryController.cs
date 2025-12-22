using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Net.Http;
using System.Text.Json;
using System.Collections.Generic;

namespace _3_Web_UI_ASPNET.Controllers
{
    public class HistoryController : Controller
    {
        private readonly HttpClient _httpClient;
        private const string API_BASE_URL = "http://localhost:3000";

        public HistoryController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new System.Uri(API_BASE_URL);
        }

        public async Task<IActionResult> List()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
            {
                return RedirectToAction("Login", "Account");
            }

            var userId = HttpContext.Session.GetString("user_id") ?? "1";
            ViewBag.UserRole = HttpContext.Session.GetString("role") ?? "";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "user";
            ViewBag.IsLoggedIn = true;

            try
            {
                // API'den kullanıcıya özel tahmin geçmişini çek
                var response = await _httpClient.GetAsync($"/api/predictions/user/{userId}");
                if (response.IsSuccessStatusCode)
                {
                    var content = await response.Content.ReadAsStringAsync();
                    var predictionsArray = JsonSerializer.Deserialize<JsonElement>(content);
                    var history = new List<dynamic>();

                    if (predictionsArray.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var pred in predictionsArray.EnumerateArray())
                        {
                            var specsLabel = "";
                            if (pred.TryGetProperty("specs_label", out var label))
                                specsLabel = label.GetString() ?? "";
                            else if (pred.TryGetProperty("model_name", out var model) && pred.TryGetProperty("segment_name", out var segment))
                                specsLabel = $"{model.GetString()} {segment.GetString()}";
                            
                            var conditionName = "";
                            if (pred.TryGetProperty("condition_name", out var cond))
                                conditionName = cond.GetString() ?? "";

                            var priceElement = pred.GetProperty("predicted_price");
                            var price = priceElement.ValueKind == JsonValueKind.Number 
                                ? priceElement.GetDouble().ToString("F2") 
                                : priceElement.GetString() ?? "0";

                            var dateElement = pred.GetProperty("created_at");
                            var dateStr = dateElement.GetString() ?? DateTime.Now.ToString("dd.MM.yyyy");
                            var tarih = dateStr.Length > 10 ? dateStr.Substring(0, 10) : dateStr;
                            tarih = tarih.Replace("-", ".");

                            history.Add(new
                            {
                                Tarih = tarih,
                                Cihaz = $"{specsLabel} ({conditionName})",
                                Fiyat = price
                            });
                        }
                    }
                    ViewBag.History = history;
                }
                else
                {
                    ViewBag.History = new List<dynamic>();
                }
            }
            catch
            {
                // Hata durumunda boş liste
                ViewBag.History = new List<dynamic>();
            }

            return View();
        }

        public IActionResult Details(string id)
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
            {
                return RedirectToAction("Login", "Account");
            }
            ViewBag.UserRole = HttpContext.Session.GetString("role") ?? "";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            // Sadece demo - API ile tüm tahmin detayları alınabilir
            ViewBag.Detail = new { Id = id, Model = "iPhone 14 Pro", Specs = "256GB, 8GB RAM", Fiyat = "45400", Status = "Mükemmel", Tarih = "02.12.2025" };
            return View();
        }
    }
}
