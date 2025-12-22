using Microsoft.EntityFrameworkCore;
using _3_Web_UI_ASPNET.Models;

namespace _3_Web_UI_ASPNET.Data
{
    public class AppDbContext : DbContext
    {
        public AppDbContext(DbContextOptions<AppDbContext> options) : base(options)
        {
        }

        public DbSet<SystemLog> SystemLogs { get; set; }
        public DbSet<User> Users { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<SystemLog>().ToTable("system_logs");
            modelBuilder.Entity<User>().ToTable("users");
        }
    }
}
