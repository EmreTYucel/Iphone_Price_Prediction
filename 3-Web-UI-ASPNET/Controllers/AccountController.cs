using Microsoft.AspNetCore.Mvc;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http;

namespace _3_Web_UI_ASPNET.Controllers
{
    public class AccountController : Controller
    {
        private readonly HttpClient _httpClient;
        private readonly _3_Web_UI_ASPNET.Data.AppDbContext _context;
        private const string API_BASE_URL = "http://localhost:3000";

        public AccountController(IHttpClientFactory httpClientFactory, _3_Web_UI_ASPNET.Data.AppDbContext context)
        {
            _httpClient = httpClientFactory.CreateClient();
            _httpClient.BaseAddress = new System.Uri(API_BASE_URL);
            _context = context;
        }

        // Login GET
        [HttpGet]
        public IActionResult Login()
        {
            // Eğer zaten giriş yapılmışsa ana sayfaya yönlendir
            if (!string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
            {
                var role = HttpContext.Session.GetString("role");
                if (role == "Admin")
                    return RedirectToAction("Dashboard", "Admin");
                return RedirectToAction("Index", "Home");
            }
            ViewBag.IsLoggedIn = false;
            ViewBag.UserRole = "";
            ViewBag.Username = "";
            return View();
        }

        // Login post
        [HttpPost]
        public async Task<IActionResult> Login(string username, string password)
        {
            try
            {
                var loginData = new { username, password };
                var json = JsonSerializer.Serialize(loginData);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/api/auth/login", content);
                var responseContent = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode)
                {
                    var result = JsonSerializer.Deserialize<JsonElement>(responseContent);
                    if (result.GetProperty("success").GetBoolean())
                    {
                        // 1. KRİTİK DÜZELTME: Başarılı olmadan önce eski hata mesajlarını temizle
                        // Böylece ekranda kırmızı ve yeşil kutular üst üste binmez.
                        TempData.Clear();

                        var user = result.GetProperty("user");
                        var userIdElement = user.GetProperty("user_id");
                        var userId = userIdElement.ValueKind == JsonValueKind.Number
                            ? userIdElement.GetInt64().ToString()
                            : userIdElement.GetString();
                        var userName = user.GetProperty("username").GetString();
                        var rolesArray = user.GetProperty("roles");
                        var roles = new List<string>();
                        if (rolesArray.ValueKind == JsonValueKind.Array)
                        {
                            foreach (var role in rolesArray.EnumerateArray())
                            {
                                if (role.ValueKind == JsonValueKind.String)
                                    roles.Add(role.GetString() ?? "");
                            }
                        }

                        HttpContext.Session.SetString("user_id", userId ?? "0");
                        HttpContext.Session.SetString("username", userName ?? "");
                        HttpContext.Session.SetString("role", roles.Contains("Admin") ? "Admin" : "User");

                        TempData["SuccessMessage"] = "Giriş başarılı!";

                        // EF Core Logging
                        try
                        {
                            var log = new _3_Web_UI_ASPNET.Models.SystemLog
                            {
                                UserId = long.Parse(userId ?? "0"),
                                Action = "Login",
                                Description = "Kullanıcı sisteme giriş yaptı.",
                                CreatedAt = DateTime.UtcNow
                            };
                            _context.SystemLogs.Add(log);
                            await _context.SaveChangesAsync();
                        }
                        catch (Exception ex)
                        {
                            Console.WriteLine("Log Error: " + ex.Message);
                        }

                        if (roles.Contains("Admin"))
                            return RedirectToAction("Dashboard", "Admin");
                        return RedirectToAction("Index", "Home");
                    }
                    else
                    {
                        // API 200 döndü ama success:false (Şifre yanlış vb.)
                        // 2. KRİTİK DÜZELTME: Redirect yerine View döndür (Hata anında görünsün)
                        var error = JsonSerializer.Deserialize<JsonElement>(responseContent);
                        TempData["ErrorMessage"] = error.GetProperty("error").GetString() ?? "Giriş başarısız!";
                        return View();
                    }
                }
                else
                {
                    // API Hata Döndü (400, 404, 500 vb.)
                    var error = JsonSerializer.Deserialize<JsonElement>(responseContent);
                    TempData["ErrorMessage"] = error.GetProperty("error").GetString() ?? "Giriş başarısız!";
                    return View(); // Sayfayı yenileme, hatayı direkt göster
                }
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "API bağlantı hatası: " + ex.Message;
                return View(); // Sayfayı yenileme, hatayı direkt göster
            }
        }

        [HttpGet]
        public IActionResult Register()
        {
            ViewBag.IsLoggedIn = false;
            ViewBag.UserRole = "";
            ViewBag.Username = "";
            return View();
        }

        [HttpPost]
        public async Task<IActionResult> Register(string username, string email, string password, string password_confirm)
        {
            if (password != password_confirm)
            {
                TempData["ErrorMessage"] = "Şifreler uyuşmuyor.";
                return View();
            }

            try
            {
                // Role = User zorunluluğu burada korundu
                var registerData = new { username, password, email, role = "User" };
                var json = JsonSerializer.Serialize(registerData);
                var content = new StringContent(json, Encoding.UTF8, "application/json");

                var response = await _httpClient.PostAsync("/api/auth/register", content);
                var responseContent = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode)
                {
                    TempData["SuccessMessage"] = "Kayıt başarılı! Giriş yapabilirsiniz.";
                    return RedirectToAction("Login");
                }
                else
                {
                    var error = JsonSerializer.Deserialize<JsonElement>(responseContent);
                    TempData["ErrorMessage"] = error.GetProperty("error").GetString() ?? "Kayıt başarısız!";
                    return View();
                }
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "API bağlantı hatası: " + ex.Message;
                return View();
            }
        }

        public IActionResult Profile()
        {
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
                return RedirectToAction("Login");

            ViewBag.Username = HttpContext.Session.GetString("username") ?? "-";
            ViewBag.UserRole = HttpContext.Session.GetString("role") ?? "User";
            ViewBag.IsLoggedIn = true;
            return View();
        }

        public async Task<IActionResult> Logout()
        {
            // EF Core Logging
            var username = HttpContext.Session.GetString("username");
            if (!string.IsNullOrEmpty(username))
            {
                try
                {
                    var log = new _3_Web_UI_ASPNET.Models.SystemLog
                    {
                        UserId = null,
                        Action = "Logout",
                        Description = "Kullanıcı çıkış yaptı.",
                        CreatedAt = DateTime.UtcNow
                    };
                    var uid = HttpContext.Session.GetString("user_id");
                    if (!string.IsNullOrEmpty(uid)) log.UserId = long.Parse(uid);

                    _context.SystemLogs.Add(log);
                    await _context.SaveChangesAsync();
                }
                catch { }
            }

            HttpContext.Session.Clear();
            TempData["SuccessMessage"] = "Çıkış yapıldı.";
            return RedirectToAction("Login");
        }
    }
}
