namespace _3_Web_UI_ASPNET.Models
{
    /// <summary>
    /// Tahmin giriş modeli - Form verilerini taşır
    /// </summary>
    public class PredictionInputModel
    {
        public int? SpecsId { get; set; }
        public int? ConditionId { get; set; }
        public int? ModelId { get; set; }
        
        // Manuel giriş alanları
        public int? RamGb { get; set; }
        public int? HafizaGb { get; set; }
        public int? KameraMp { get; set; }
        public decimal? EkranBoyutu { get; set; }
        public int? BataryaMah { get; set; }
        public int? ReleaseYear { get; set; }
        
        // Kullanıcı bilgisi
        public int? UserId { get; set; }
    }
}
