// Sayfa tamamen yüklendiğinde çalışır
document.addEventListener("DOMContentLoaded", function () {

    // Ekranda 'alert' sınıfına sahip (bildirim) kutularını bulur
    var bildirimler = document.querySelectorAll('.alert');

    // Her bir bildirim için süre sayacı başlatır
    bildirimler.forEach(function (kutu) {

        // 4 saniye (4000 milisaniye) bekle
        setTimeout(function () {
            // Kutunun opaklığını sıfıra indir (yavaşça kaybolma efekti)
            kutu.style.transition = "opacity 0.5s ease";
            kutu.style.opacity = "0";

            // Efekt bitince (0.5 sn sonra) tamamen ekrandan sil
            setTimeout(function () {
                kutu.remove();
            }, 500);

        }, 4000); // Mesajın ekranda kalma süresi (4 saniye)
    });
});