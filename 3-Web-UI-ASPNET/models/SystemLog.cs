using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace _3_Web_UI_ASPNET.Models
{
    [Table("system_logs")]
    public class SystemLog
    {
        [Key]
        [Column("log_id")]
        public int LogId { get; set; }

        [Column("user_id")]
        public long? UserId { get; set; }

        // Navigation property for Foreign Key relationship
        [ForeignKey("UserId")]
        public User User { get; set; } = null!;

        [Column("action")]
        public string Action { get; set; } = null!;

        [Column("description")]
        public string Description { get; set; } = null!;

        [Column("created_at")]
        public DateTime CreatedAt { get; set; } = DateTime.Now;
    }
}
