using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace _3_Web_UI_ASPNET.Models
{
    [Table("users")]
    public class User
    {
        [Key]
        [Column("user_id")]
        public long UserId { get; set; }

        [Column("username")]
        public string Username { get; set; } = null!;
        
        // Diğer alanlara gerek yok, sadece isim için bağlanıyoruz
    }
}
