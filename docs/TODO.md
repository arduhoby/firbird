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

- [x] BirdNET etiketleriyle eşleşen türleri, görüntü aday paketinden bağımsız `Türkiye ses kataloğu` olarak üret; kaynak dosyaları ve eşleşmeyen adları katalog içinde kayda al.
- [x] Ses kataloğundaki bozuk UTF-8 Türkçe tür adlarını üretim aşamasında düzelt; `Kaya Güvercini` gibi adlar canlı kartta doğru görünmeli.
- [x] Arıkuşu (*Merops apiaster*) için ses katalog regresyon testi ekle; katalogda bulunduğunu doğrula. Saha kaydında tanınmama vakasını model/karar eşiği testi olarak ayrıca izle.
- [ ] Arıkuşu saha kaydında ham BirdNET adaylarını, skorunu ve canlı kararının kabul/ret nedenini kayda al; katalog, model ve karar eşiği kaynaklarını ayrı ayrı doğrula.
- [x] Ses sonuçlarında yalnızca yüklü Türkiye aday paketinde bilimsel adla eşleşen türleri göster; küresel modelin bölge dışı etiketlerini tespit olarak sunma.
- [x] Kuş dışı BirdNET sınıflarını alt metin yerine tam sınıf adıyla ele; `Carduelis` ve `flycatcher` gibi gerçek kuşları koruyan regresyon testleri ekle.
- [x] Mikrofonu üç saniyede bir durdurmak yerine kesintisiz PCM kaydet; her saniye son üç saniyelik örtüşen pencereyi analiz et.
- [x] Bölgesel desteği olmayan düşük/orta güvenli tekrarların ana tespit listesine yükselmesini engelle.
- [ ] Görüntü adayları, BirdNET ses etiketleri ve Türkiye kataloğu arasındaki kesişimi bilimsel adla raporla; her sayının kaynak dosyasını, model sürümünü ve rapor tarihini ekle.
- [ ] Taksonomik eş adları ayrı bir doğrulama tablosunda uzlaştır; doğrudan ad eşleşmesi olmayan türü destekleniyor diye işaretleme.
- [ ] Ağustos böceği ve benzeri sürekli böcek sesleri için negatif örnek test seti oluştur; ses benzerliğiyle kuş tahmini üretmediğini saha kayıtlarıyla doğrula.

## Faz 4 — Kayıt oynatımı ve saha bilgisi

- [x] Uzun kayıtlarda spektrogramı ekrana sıkıştırma; kayıt anındaki zaman çözünürlüğünü koruyarak yatay kaydırılabilir göster.
- [x] Kuş tespit çizgilerini ve adlarını yatay zaman şeridinde okunur tut; tıklanınca ilgili saniyeye git.
- [x] Tamamlanan ses kaydını kullanıcıya açık `Download/FirBird` klasörüne kaydet ve bu konumu ekranda bildir.
- [ ] Kayıt ekranı ve oynatıcıda oturumun tarihini, yer adını ve GPS koordinatını göster.

## Canlı dinleme güvenilirliği

- [x] Canlı dinleme/kayıt aktifken ekranın uykuya geçmesini engelle; ekran kilidi veya ekranın kapanması kaydı ve ses analizi kesmemeli.
- [x] Canlı dinlemenin 10. dakikasında devam/sonlandır seçeneği sun; ileti bir dakika yanıtsız kalırsa varsayılan olarak kayda devam et.
- [x] Yeni canlı oturumlarda her akustik olayı başlangıç/bitiş zamanı ve güveniyle sakla; geçmiş player’da aynı çizgileri kullan.
- [x] Eski, parça parça kayıt geçmişini kaldır; yeni oturumları tek kesintisiz WAV kaydı ve tek oynatıcı akışıyla sakla.
- [x] Oynatıcıda önceki/sonraki tespit atlamasını ve %50–400 ses yükseltmeyi ekle.

## Faz 6 — Zamansal bağlamla ses tespiti

- [x] Cihaz saati yerine GPS konumu, tarih ve güneş konumu hesaplarını kullan; sivil/denizcilik/astronomik alacakaranlık eşiğini açıkça tanımla.
- [x] Türlere gececil, gündüzcül ve gece de ötebilen gündüzcül davranış sınıfı ata; başlangıç kaynaklarını ve sınırlarını dokümante et.
- [x] Saat bilgisini kesin eleme değil, model güvenine uygulanan yumuşak olasılık ağırlığı olarak uygula.
- [x] Bülbül, kamışçın, kızılgerdan ve karakızılkuyruğu gece otomatik olarak eleme; baykuş ve çobanaldatan gibi gececil türler için uygun ağırlık kullan.
- [x] Ağaçkakan, şahin ve benzeri belirgin gündüzcül türlerde gece güvenini düşür; yüksek ham model güveni sonucu gizlemez.
- [x] Canlı listede ve kaydedilmiş player olayında zaman bağlamının etkisini göster: `gece etkinliği`, `alacakaranlık` veya `gündüz etkinliği`.
- [x] Güneş konumu hesabında UTC saatini yalnızca bir kez uygula; geç saatlerde gündüz hatasını önleyen regresyon örneği ekle.
- [x] Canlı kuş kartında zaman bağlamını standart güneş/ay/alacakaranlık ikonu ve kısa rozetle göster; bölgesel bağlam metnini kompaktlaştır.
- [ ] Türkiye’de farklı mevsim, şehir ışığı ve göç gecesi örnekleriyle regresyon testi oluştur; yanlış negatif/pozitif değişimini ölç.

## Video: görüntü ve sesin birlikte tanımlanması (sonraki aşama)

- [ ] Videodan sesi çıkarıp BirdNET ile; seçilmiş kareleri ise görüntü modeliyle ayrı ayrı analiz et.
- [ ] Görüntü modelinin desteklediği 464 tür ile ses modelinin Türkiye paketindeki destek kapsamını ayrı tut; bir kanalda bulunamayan türü diğer kanaldan eleme.
- [ ] Tür skorlarını aynı zaman aralığında birleştir: iki kanal aynı türü destekliyorsa güveni yükselt; yalnızca tek kanaldan kanıt varsa sonucu bu kaynakla göster.
- [ ] Sonuç kartında kanıtı açıkça yaz: `Görüntü + ses`, `yalnızca ses` veya `yalnızca görüntü`; ilgili zaman damgasına atlama ekle.
- [ ] Çelişen ses/görüntü tahminlerinde tek tür dayatma; iki adayı ve güven düzeylerini kullanıcıya göster.
