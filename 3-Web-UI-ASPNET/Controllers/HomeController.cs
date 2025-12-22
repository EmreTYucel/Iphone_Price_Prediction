using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Http;

namespace _3_Web_UI_ASPNET.Controllers
{
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            // Eğer giriş yapılmamışsa login'e yönlendir
            if (string.IsNullOrEmpty(HttpContext.Session.GetString("username")))
            {
                return RedirectToAction("Login", "Account");
            }

            ViewBag.UserRole = HttpContext.Session.GetString("role") ?? "";
            ViewBag.IsLoggedIn = true;
            ViewBag.Username = HttpContext.Session.GetString("username") ?? "";
            return View();
        }
    }
}
