using Microsoft.AspNetCore.Mvc;
using _3_Web_UI_ASPNET.Data; // AppDbContext namespace'i
using System.Linq;
using Microsoft.AspNetCore.Http;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;

namespace _3_Web_UI_ASPNET.Controllers
{
    public class SystemLogsController : Controller
    {
        private readonly AppDbContext _context;

        public SystemLogsController(AppDbContext context)
        {
            _context = context;
        }

        public async Task<IActionResult> Index()
        {
            // Sadece Admin erişebilir
            if (HttpContext.Session.GetString("role") != "Admin")
            {
                return RedirectToAction("Login", "Account");
            }

            var logs = await _context.SystemLogs
                                     .Include(x => x.User)
                                     .OrderByDescending(x => x.CreatedAt)
                                     .Take(100)
                                     .ToListAsync();
            
            ViewBag.Username = HttpContext.Session.GetString("username");
            ViewBag.UserRole = "Admin";
            ViewBag.IsLoggedIn = true;

            return View(logs);
        }

        [HttpPost]
        public async Task<IActionResult> ClearAllLogs()
        {
            // Tüm logları sil
            var allLogs = await _context.SystemLogs.ToListAsync();
            _context.SystemLogs.RemoveRange(allLogs);
            await _context.SaveChangesAsync();

            TempData["SuccessMessage"] = "Tüm log kayıtları başarıyla silindi.";
            return RedirectToAction("Index");
        }
    }
}
