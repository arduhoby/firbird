# FirBird Yapılacaklar

## v0.5.0 — Canlı dinleme ve çevrimdışı eBird bağlamı

- [x] Uygulama sürümünü `0.5.0` olarak başlat.
- [x] eBird API anahtarını APK'ya koymadan Türkiye hotspot ve son gözlem verisini çevrimdışı paketleyen aracı ekle.
- [x] Paket içinde kaynak adı, sorgu adresi, UTC indirme tarihi, parametreler, kayıt sayıları ve dosya özetlerini tut.
- [x] Uygulama tarafında paket şemasını, Türkiye kapsamını, kayıt sayılarını ve koordinatları doğrula.
- [x] GPS'e göre 20/50 km içindeki hotspot'ları ve en yakın noktayı cihaz üzerinde hesapla.
- [x] Canlı kuş kartında ses modeli güveni ve bölgesel destek rozetini; ayrıntı panelinde birleşik güveni ayrı göster.
- [x] Karta dokununca yakındaki gözlem noktaları ve tarihlerini kayıt kesilmeden göster.
- [ ] Aynı kanıt anlık görüntüsünü kayda ekle ve tek player ekranında yeniden kullan.
- [ ] Sol menüye çevrimdışı liste ve isteğe bağlı çevrimiçi harita içeren `Yakındaki Gözlem Noktaları` ekranını ekle.
- [x] Arama yarıçapını ayarlardan 20 km veya 50 km olarak seçilebilir yap; özel değer seçimini sonraki arayüz turuna bırak.
- [ ] Harita zemininin internet gerektirdiğini açıkça bildir; harita döşemelerini Türkiye paketine ekleme.

## Türkiye tür listesi uyumu

- [ ] Mevcut 464 tür aday paketini TRAKUŞ'un belgeli 513 tür listesi ve Türkiye Kuş Kayıt Komitesi'nin 505 tür listesiyle bilimsel ad üzerinden karşılaştır.
- [ ] Her farkı düzenli/göçmen, nadir, belgeli, tartışmalı veya listeden çıkarıldı durumuyla; kaynak ve tarih bilgisiyle kayda al.
- [ ] TRAKUŞ verisinin uygulama içinde yeniden kullanımı için izin/lisans durumunu teyit et; onaysız otomatik veri kopyalama yapma.
- [ ] Tanımlama aday vektörü bulunan türleri yalnızca keşif listesinde bulunan türlerden ayır ve ekranda açıkça belirt.
- [ ] Doğrulanmış listeyi sürümlü Türkiye katalog paketine dönüştür; 464/503 gibi sabit sayı metinlerini katalogdan üret.

- [ ] Her tür sayısının yanında kaynak adı, kaynak tarihi ve hesaplama yöntemi yer almalı; doğrulanmamış sayılar kesin bilgi gibi gösterilmemeli.

## Model kapsamı ve yanlış tespit koruması

- [x] Ses sonuçlarında yalnızca yüklü Türkiye aday paketinde bilimsel adla eşleşen türleri göster; küresel modelin bölge dışı etiketlerini tespit olarak sunma.
- [ ] Görüntü adayları, BirdNET ses etiketleri ve Türkiye kataloğu arasındaki kesişimi bilimsel adla raporla; her sayının kaynak dosyasını, model sürümünü ve rapor tarihini ekle.
- [ ] Taksonomik eş adları ayrı bir doğrulama tablosunda uzlaştır; doğrudan ad eşleşmesi olmayan türü destekleniyor diye işaretleme.
- [ ] Ağustos böceği ve benzeri sürekli böcek sesleri için negatif örnek test seti oluştur; ses benzerliğiyle kuş tahmini üretmediğini saha kayıtlarıyla doğrula.

## Video: görüntü ve sesin birlikte tanımlanması

- [ ] Videodan sesi çıkarıp BirdNET ile; seçilmiş kareleri ise görüntü modeliyle ayrı ayrı analiz et.
- [ ] Görüntü modelinin desteklediği 464 tür ile ses modelinin Türkiye paketindeki destek kapsamını ayrı tut; bir kanalda bulunamayan türü diğer kanaldan eleme.
- [ ] Tür skorlarını aynı zaman aralığında birleştir: iki kanal aynı türü destekliyorsa güveni yükselt; yalnızca tek kanaldan kanıt varsa sonucu bu kaynakla göster.
- [ ] Sonuç kartında kanıtı açıkça yaz: `Görüntü + ses`, `yalnızca ses` veya `yalnızca görüntü`; ilgili zaman damgasına atlama ekle.
- [ ] Çelişen ses/görüntü tahminlerinde tek tür dayatma; iki adayı ve güven düzeylerini kullanıcıya göster.

## Faz 4 — Kayıt oynatımı ve saha bilgisi

- [x] Uzun kayıtlarda spektrogramı ekrana sıkıştırma; kayıt anındaki zaman çözünürlüğünü koruyarak yatay kaydırılabilir göster.
- [x] Kuş tespit çizgilerini ve adlarını yatay zaman şeridinde okunur tut; tıklanınca ilgili saniyeye git.
- [x] Tamamlanan ses kaydını kullanıcıya açık `Download/FirBird` klasörüne kaydet ve bu konumu ekranda bildir.
- [ ] Kayıt ekranı ve oynatıcıda oturumun tarihini, yer adını ve GPS koordinatını göster.

## Canlı dinleme güvenilirliği

- [ ] Canlı dinleme/kayıt aktifken ekranın uykuya geçmesini engelle; ekran kilidi veya ekranın kapanması kaydı ve ses analizi kesmemeli.
- [ ] Canlı dinlemenin 10. dakikasında devam/sonlandır seçeneği sun; ileti bir dakika yanıtsız kalırsa varsayılan olarak kayda devam et.
