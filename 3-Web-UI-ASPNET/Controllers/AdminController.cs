using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Collections.Generic;
using System.Linq;

namespace _3_Web_UI_ASPNET.Controllers
{
    public class AdminController : Controller
    {
        private readonly HttpClient _httpClient;
        private const string API_BASE_URL = "http://127.0.0.1:3000";

        public AdminController(IHttpClientFactory httpClientFactory)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new System.Uri(API_BASE_URL);
        }

        public async Task<IActionResult> Dashboard()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
            {
                return RedirectToAction("Login", "Account");
            }
            var role = HttpContext.Session.GetString("role");
            if (role != "Admin")
            {
                return RedirectToAction("Index", "Home");
            }

            var jsonOptions = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

            // 1. Dashboard İstatistikleri
            try
            {
                var statsResponse = await _httpClient.GetAsync("/api/admin/dashboard-stats");
                if (statsResponse.IsSuccessStatusCode)
                {
                    var statsContent = await statsResponse.Content.ReadAsStringAsync();
                    var stats = JsonSerializer.Deserialize<JsonElement>(statsContent, jsonOptions);
                    
                    // Güvenli veri okuma
                    if (stats.TryGetProperty("totalUsers", out var tu) && tu.ValueKind == JsonValueKind.Number)
                        ViewBag.TotalUsers = tu.GetInt32();
                    else 
                        ViewBag.TotalUsers = 0;

                    if (stats.TryGetProperty("totalPredictions", out var tp) && tp.ValueKind == JsonValueKind.Number)
                        ViewBag.TotalPredictions = tp.GetInt32();
                    else
                        ViewBag.TotalPredictions = 0;

                    // Yeni eklenen istatistikler
                    if (stats.TryGetProperty("totalModels", out var tm) && tm.ValueKind == JsonValueKind.Number)
                        ViewBag.TotalModels = tm.GetInt32();
                    else
                        ViewBag.TotalModels = 0;

                    if (stats.TryGetProperty("avgPredictedPrice", out var ap) && ap.ValueKind == JsonValueKind.Number)
                        ViewBag.AvgPrice = ap.GetDouble().ToString("N2"); // Formatlı (kuruslu)
                    else if (stats.TryGetProperty("avgPredictedPrice", out var apStr) && apStr.ValueKind == JsonValueKind.String)
                         ViewBag.AvgPrice = apStr.GetString();
                    else
                        ViewBag.AvgPrice = "0.00";
                }
                else
                {
                    ViewBag.TotalUsers = 0;
                    ViewBag.TotalPredictions = 0;
                    ViewBag.TotalModels = 0;
                    ViewBag.AvgPrice = "0";
                }
            }
            catch
            {
                ViewBag.TotalUsers = 0;
                ViewBag.TotalPredictions = 0;
            }

            // 2. Maskeli Kullanıcı Listesi
            try
            {
                var usersResponse = await _httpClient.GetAsync("/api/users/masked");
                if (usersResponse.IsSuccessStatusCode)
                {
                    var usersContent = await usersResponse.Content.ReadAsStringAsync();
                    var usersArray = JsonSerializer.Deserialize<JsonElement>(usersContent, jsonOptions);
                    var usersList = new List<dynamic>();
                    if (usersArray.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var user in usersArray.EnumerateArray())
                        {
                            usersList.Add(new
                            {
                                Id = user.TryGetProperty("user_id", out var uid) ? (uid.ValueKind == JsonValueKind.Number ? uid.GetInt64() : 0) : 0,
                                Username = user.TryGetProperty("username_masked", out var um) ? um.GetString() : "",
                                Email = user.TryGetProperty("email_masked", out var em) ? em.GetString() : "",
                                Tarih = user.TryGetProperty("created_at", out var ca) ? (ca.GetString()?.Substring(0, 10) ?? "") : "",
                                Role = user.TryGetProperty("role_name", out var rn) ? rn.GetString() : "User"
                            });
                        }
                    }
                    ViewBag.Users = usersList;
                }
                else
                {
                    ViewBag.Users = new List<dynamic>();
                }
            }
            catch
            {
                ViewBag.Users = new List<dynamic>();
            }

            // 3. Son Tahminler (Son 5)
            try
            {
                var predsResponse = await _httpClient.GetAsync("/api/predictions");
                if (predsResponse.IsSuccessStatusCode)
                {
                    var predsContent = await predsResponse.Content.ReadAsStringAsync();
                    var predsArray = JsonSerializer.Deserialize<JsonElement>(predsContent, jsonOptions);
                    var predsList = new List<dynamic>();
                    if (predsArray.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var p in predsArray.EnumerateArray())
                        {
                            var tarih = "";
                            if (p.TryGetProperty("created_at", out var ca)) tarih = ca.GetString() ?? "";
                            
                            var kullanici = "";
                            if (p.TryGetProperty("username", out var un)) kullanici = un.GetString() ?? "";
                            else if (p.TryGetProperty("user_id", out var uid)) kullanici = uid.ToString();
                            
                            // Maskeleme: ilk 2 harf + ***
                            if (!string.IsNullOrEmpty(kullanici) && kullanici.Length > 2)
                            {
                                kullanici = kullanici.Substring(0, 2) + "***";
                            }
                            else if (!string.IsNullOrEmpty(kullanici))
                            {
                                kullanici = kullanici + "***";
                            }

                            var cihaz = "";
                            if (p.TryGetProperty("specs_label", out var sl)) cihaz = sl.GetString() ?? "";
                            else {
                                var model = p.TryGetProperty("model_name", out var mn) ? mn.GetString() : "";
                                var segment = p.TryGetProperty("segment_name", out var sn) ? sn.GetString() : "";
                                cihaz = $"{model} {segment}".Trim();
                            }

                            var fiyat = "";
                            if (p.TryGetProperty("predicted_price", out var pp)) fiyat = pp.ToString();
                            
                            predsList.Add(new { Tarih = tarih, Kullanici = kullanici, Cihaz = cihaz, Fiyat = fiyat });
                        }
                    }
                    // Sadece son 5 tanesini ve tarih sırasına göre al
                    ViewBag.AdminPredictions = predsList.Take(5).ToList();
                }
                else
                {
                    ViewBag.AdminPredictions = new List<dynamic>();
                }
            }
            catch
            {
                ViewBag.AdminPredictions = new List<dynamic>();
            }

            ViewBag.UserRole = "Admin";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            return View();
        }

        public async Task<IActionResult> Predictions()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")) || HttpContext.Session.GetString("role") != "Admin")
            {
                return RedirectToAction("Login", "Account");
            }

            try
            {
                var predsResponse = await _httpClient.GetAsync("/api/predictions");
                if (predsResponse.IsSuccessStatusCode)
                {
                    var predsContent = await predsResponse.Content.ReadAsStringAsync();
                    var predsArray = JsonSerializer.Deserialize<JsonElement>(predsContent);
                    var predsList = new List<dynamic>();
                    if (predsArray.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var p in predsArray.EnumerateArray())
                        {
                            var tarih = "";
                            if (p.TryGetProperty("created_at", out var ca)) tarih = ca.GetString() ?? "";
                            var kullanici = "";
                            if (p.TryGetProperty("username", out var un)) kullanici = un.GetString() ?? "";
                            else if (p.TryGetProperty("user_id", out var uid)) kullanici = uid.GetInt64().ToString();

                            // Maskeleme
                            if (!string.IsNullOrEmpty(kullanici) && kullanici.Length > 2)
                            {
                                kullanici = kullanici.Substring(0, 2) + "***";
                            }
                            else if (!string.IsNullOrEmpty(kullanici))
                            {
                                kullanici = kullanici + "***";
                            }

                            var cihaz = "";
                            if (p.TryGetProperty("specs_label", out var sl)) cihaz = sl.GetString() ?? "";
                            
                            var fiyat = "";
                            if (p.TryGetProperty("predicted_price", out var pp)) fiyat = pp.ToString();

                            predsList.Add(new { Tarih = tarih, Kullanici = kullanici, Cihaz = cihaz, Fiyat = fiyat });
                        }
                    }
                    ViewBag.Predictions = predsList;
                }
                else
                {
                    ViewBag.Predictions = new List<dynamic>();
                }
            }
            catch
            {
                ViewBag.Predictions = new List<dynamic>();
            }

            ViewBag.UserRole = "Admin";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            return View();

        }

        public async Task<IActionResult> Users()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")) || HttpContext.Session.GetString("role") != "Admin")
            {
                return RedirectToAction("Login", "Account");
            }

            try
            {
                var usersResponse = await _httpClient.GetAsync("/api/users/masked");
                if (usersResponse.IsSuccessStatusCode)
                {
                    var usersContent = await usersResponse.Content.ReadAsStringAsync();
                    var usersArray = JsonSerializer.Deserialize<JsonElement>(usersContent);
                    var usersList = new List<dynamic>();
                    if (usersArray.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var user in usersArray.EnumerateArray())
                        {
                            usersList.Add(new
                            {
                                Id = user.GetProperty("user_id").GetInt64(),
                                Username = user.GetProperty("username_masked").GetString() ?? "",
                                Email = user.GetProperty("email_masked").GetString() ?? "",
                                Tarih = user.TryGetProperty("created_at", out var createdAt) 
                                    ? createdAt.GetString()?.Substring(0, 10) ?? ""
                                    : ""
                            });
                        }
                    }
                    ViewBag.Users = usersList;
                }
                else
                {
                    ViewBag.Users = new List<dynamic>();
                }
            }
            catch
            {
                ViewBag.Users = new List<dynamic>();
            }

            ViewBag.UserRole = "Admin";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            return View();
        }

        public class CreateUserRequest
        {
            public string username { get; set; } = null!;
            public string password { get; set; } = null!;
            public string email { get; set; } = null!;
            public string role { get; set; } = "User";
        }

        public class RoleRequest
        {
            public string roleName { get; set; } = null!;
        }

        [HttpPost]
        public async Task<IActionResult> CreateUser([FromBody] CreateUserRequest model)
        {
            if (HttpContext.Session.GetString("role") != "Admin")
            {
                return Json(new { success = false, error = "Yetkisiz erişim" });
            }

            try
            {
                // Önce kullanıcı oluştur
                var json = JsonSerializer.Serialize(model);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var registerResponse = await _httpClient.PostAsync("/api/auth/register", content);
                var registerContent = await registerResponse.Content.ReadAsStringAsync();

                if (registerResponse.IsSuccessStatusCode)
                {
                    var result = JsonSerializer.Deserialize<JsonElement>(registerContent);
                    string userId = "";
                    
                    if (result.TryGetProperty("user_id", out var uidElement))
                    {
                        if (uidElement.ValueKind == JsonValueKind.Number)
                            userId = uidElement.GetInt64().ToString();
                        else if (uidElement.ValueKind == JsonValueKind.String)
                            userId = uidElement.GetString() ?? "";
                    }

                    // Seçilen rolü ata (Varsayılan User zaten atanmış olabilir ama biz yine de tetikleyelim veya Admin ise onu atayalım)
                    // create_user SP'si zaten bir rol atıyor. Eğer Admin seçildiyse Admin rolünü ekleyelim/değiştirelim.
                    if (!string.IsNullOrEmpty(userId) && model.role == "Admin") 
                    {
                         var roleData = new { role_name = "Admin" };
                         var roleJson = JsonSerializer.Serialize(roleData);
                         var roleContent = new StringContent(roleJson, Encoding.UTF8, "application/json");
                         await _httpClient.PostAsync($"/api/users/{userId}/roles", roleContent);
                    }
                    // Eğer User seçildiyse zaten varsayılan User geliyor ancak yine de emin olmak için gerekirse User rolünü atayabiliriz.
                    // Fakat veritabanı mantığında çift rol oluşmasın diye, burada sadece Admin ise ekleme yapıyoruz.
                    // Daha temiz bir yapı için SwitchRole benzeri bir mantıkla eski rolü silip yenisini atamak en doğrusu olurdu ama şimdilik bu yeterli.

                    return Json(new { success = true, message = "Kullanıcı oluşturuldu" });
                }
                else
                {
                    var error = JsonSerializer.Deserialize<JsonElement>(registerContent);
                    return Json(new { success = false, error = error.TryGetProperty("error", out var err) ? err.GetString() : "Kayıt hatası" });
                }
            }
            catch (Exception ex)
            {
                return Json(new { success = false, error = ex.Message });
            }
        }

        [HttpPost]
        public async Task<IActionResult> DeleteUser(int id)
        {
            if (HttpContext.Session.GetString("role") != "Admin") return Json(new { success = false, error = "Yetkisiz" });
            
            // Kendini silme koruması
            var currentUserId = HttpContext.Session.GetString("user_id");
            if (!string.IsNullOrEmpty(currentUserId) && currentUserId == id.ToString())
            {
                return Json(new { success = false, error = "Kendinizi silemezsiniz." });
            }

            try
            {
                var response = await _httpClient.DeleteAsync($"/api/users/{id}");
                return Json(new { success = response.IsSuccessStatusCode });
            }
            catch (Exception ex) { return Json(new { success = false, error = ex.Message }); }
        }

        [HttpPost]
        public async Task<IActionResult> SwitchRole(int id, string role)
        {
            if (HttpContext.Session.GetString("role") != "Admin") return Json(new { success = false, error = "Yetkisiz" });

            // Kendini değiştirme koruması
            var currentUserId = HttpContext.Session.GetString("user_id");
            if (!string.IsNullOrEmpty(currentUserId) && currentUserId == id.ToString())
            {
                return Json(new { success = false, error = "Kendi rolünüzü değiştiremezsiniz." });
            }

            try
            {
                var data = new { role_name = role };
                var content = new StringContent(JsonSerializer.Serialize(data), Encoding.UTF8, "application/json");
                var response = await _httpClient.PostAsync($"/api/users/{id}/roles", content);
                return Json(new { success = response.IsSuccessStatusCode });
            }
            catch (Exception ex) { return Json(new { success = false, error = ex.Message }); }
        }

        public IActionResult Statistics() 
        { 
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")) || HttpContext.Session.GetString("role") != "Admin")
            {
                return RedirectToAction("Login", "Account");
            }
            ViewBag.UserRole = "Admin";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            return View(); 
        }
        public IActionResult ModelCrud() 
        { 
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")) || HttpContext.Session.GetString("role") != "Admin")
            {
                return RedirectToAction("Login", "Account");
            }
            ViewBag.UserRole = "Admin";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            return View(); 
        }
        public IActionResult UpdateModel()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")) || HttpContext.Session.GetString("role") != "Admin")
            {
                return RedirectToAction("Login", "Account");
            }
            ViewBag.UserRole = "Admin";
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            ViewBag.IsLoggedIn = true;
            return View();
        }
    }
}
