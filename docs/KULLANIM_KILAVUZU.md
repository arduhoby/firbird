# FirBird 3 Kullanım Kılavuzu

Bu kılavuz FirBird 3'ün v0.8.9 sürümü içindir. Uygulama kuş gözlemi için
yardımcı bir araçtır; uzman doğrulamasının yerine geçmez.

Kılavuz uygulamaya gömülüdür ve internet bağlantısı gerektirmez. Sol menüdeki
**Kullanım Kılavuzu** seçeneğinden veya ekranların sağ üstündeki soru işaretinden
açılabilir.

## İlk kurulum

İlk açılışta uygulama ihtiyacınız olan özelliğe göre izin ister.

| İzin | Kullanım amacı | Verilmezse |
| --- | --- | --- |
| Kamera | Yeni kuş fotoğrafı çekmek | Galeriden fotoğraf seçilebilir. |
| Fotoğraf/medya | Galeri veya ses dosyası seçmek | İlgili dosya seçimi çalışmaz. |
| Mikrofon | Canlı dinleme ve WAV kaydı | Canlı ses tespiti çalışmaz. |
| Konum | Yakın türler, hotspotlar ve bölgesel bağlam | Tanımlama çalışır; yakın çevre sonucu daraltılamaz. |

## Ana bölümler

Sol üstteki menüden ana ekranlar açılır.

| Bölüm | Amaç |
| --- | --- |
| Fotoğraftan Tanımla | Kamera, galeri veya ses dosyasından analiz başlatır. |
| Canlı Ses Tespiti | Mikrofonla sürekli dinleme ve kayıt yapar. |
| Geçmiş | Kaydedilmiş analiz ve canlı oturumları açar. |
| Yakınımdaki Kuşlar | GPS çevresindeki mevsimsel türleri ve eBird hotspotlarını gösterir. |
| Ayarlar | Filtre ekolayzeri, eşikler, tema, paket bilgisi ve kişisel eBird anahtarını yönetir. |
| Kullanım Kılavuzu | Kart renklerini, nadir uyarısını, ses filtresini ve Kanıt Dosyası alanlarını uygulama içinde açıklar. |

## Fotoğraftan kuş tanımlama

1. Ana ekrandan **Fotoğraftan Tanımla** seçeneğine dokunun.
2. **Galeriden Fotoğraf**, **Anlık Fotoğraf / Kamera İle** veya ses dosyası
   seçeneğini kullanın.
3. Analiz tamamlanınca aday kartlarındaki Türkçe ad, bilimsel ad, fotoğraf ve
   güven bilgisini inceleyin.
4. Bir adaya dokunarak tür ayrıntısını açın.

Net, iyi aydınlatılmış ve kuşun kadrajda büyük olduğu fotoğraflar daha iyi
sonuç verir. EXIF tarih/konum bilgisi varsa bağlam değerlendirmesinde
kullanılabilir; yoksa tanımlama yine yapılır.

## Canlı ses tespiti ve ses filtresi (ekolayzer)

1. Menüden **Canlı Ses Tespiti** ekranını açın.
2. Model hazır olunca ekrandaki mikrofon düğmesine dokunun. Ekranı açmak tek
   başına kayıt veya dinleme başlatmaz.
3. İstenirse mikrofon ve konum izinlerini verin; dinleme bundan sonra başlar.
4. Tespitleri zaman damgası ve güven bilgisiyle takip edin.
5. Bir karta dokunarak ses modeli, bölgesel destek ve yakın hotspot bilgisini
   inceleyin.
6. Tespiti **Doğru** ya da **Doğru değil** olarak işaretleyin. Kartı sağa
   kaydırmak da doğrulama akışını açar.
7. Oturumu bitirdiğinizde WAV kaydı ve tespit zaman çizelgesi geçmişe eklenir.

### Gerçek zamanlı ses filtresi (ekolayzer)

Canlı dinleme sırasında saha gürültüleri (rüzgar, akar su/dere, yaprak sesi)
yapay zeka modelinin tahmin başarısını düşürebilir.

- **Ayarlar → Ses Filtresi** bölümünden filtreyi açabilirsiniz.
- **Hazır Profiller:** 🌬️ **Rüzgar** (1000 Hz HPF), 💧 **Dere/Su** (300 Hz HPF + %80 spektral gürültü azaltma) veya 🌿 **Orman** modlarından birini tek dokunuşla seçebilirsiniz.
- **Manuel Kontroller (Ekolayzer Slider'ları):**
  - **Rüzgar Filtresi (Kesim):** 100 Hz – 2000 Hz arası yüksek geçiren filtre. Rüzgar uğultusunu keser. *Baykuş veya kızılgerdan gibi düşük frekansta öten türleri dinlerken 100-300 Hz seviyesinde tutunuz.*
  - **Su/Dere Gürültüsü Azaltma:** %0 – %100 arası spektral çıkarma faktörü. Akarsu ve şelale gibi geniş bantlı gürültüleri basbastırır.
  - **Ses Güçlendirme:** 0.5× – 3.0× kazanç çarpanı. Uzaktaki veya zayıf duyulan kuş seslerini güçlendirir.

### Canlı dinleme sırasında harita

Canlı Ses Tespiti ekranındaki harita düğmesi, yakın gözlem noktalarını alt
sayfa olarak açar. Haritayı açmak mikrofon kaydını veya canlı analizi durdurmaz.

### Güven değeri

Güven değeri modelin ses/fotoğraf benzerliğini ifade eder. Bölgesel destek ek
bilgidir; kesin teşhis veya tarihsel görülme sıklığı değildir. Nadir türlerde
ses, fotoğraf, tarih ve saha koşullarını ayrıca doğrulayın.

### Kuş kartının renkleri

- Kartın açık pastel arka planı güven puanıdır: yeşil yüksek, turuncu orta,
  kırmızı düşük veya çelişkili güveni anlatır.
- Yeşil çerçeve yerel/göçmen, gri çerçeve bölge dışı/zor durumu gösterir.
- Mavi **Yeni / aktif** rozeti son gelen veya o anda çalan tespittir.
- Aynı tür ayrı ses olaylarında yeniden duyulursa kartta model skorlarının
  **ortalaması** ile `× duyuldu` sayısı birlikte güncellenir. Örtüşen üç
  saniyelik analiz pencereleri yeni bir duyulma sayılmaz.
- Nadirlik güven rengi değildir. Kartta **Nadir Tür** yazısı bulunur; nadir tür
  için sabit renkli çerçeve veya alt lejant maddesi kullanılmaz.

Karar verilmemiş nadir tür kartı 15 saniyede bir turuncu parıltıyla uyarır.
Karta dokunup **Doğru** veya **Doğru değil** seçmek uyarıyı durdurur. Kart yeni
tespitler nedeniyle görünür alanın dışına çıksa bile oturum raporundaki benzersiz
nadir tür sayısı korunur; aynı türün tekrarları sayıyı artırmaz.

## Kayıtlar ve oynatıcı

**Geçmiş** ekranında canlı oturumlar ve analiz kayıtları görünür. Canlı oturumu
açtığınızda oynat/durdur yapabilir, süre çubuğunda ilerleyebilir, bir tespit
kartından doğrudan o ana atlayabilir, önceki/sonraki tespiti seçebilir ve ses
seviyesini %50 ile %400 arasında değiştirebilirsiniz.

Canlı, ses dosyası ve replay kuş kartları aynı görünümdedir. Karta dokunmak
**Kanıt Dosyası**nı açar. Replay sırasında sesin tespit anına gitmek için kartın
sağındaki ayrı oynat düğmesini kullanın.

## Kanıt Dosyası ve puanlama

Kanıt Dosyası model güvenini; saat/etkinlik, eBird yakın çevre kayıtları,
mevsim ve cihazdaki kullanıcı doğrulamalarıyla birlikte gösterir. Her satırda
puan, açıklama ve veri kaynağı bulunur. eBird kaydı kuşun aynı saatte bölgede
görüldüğünü destekler; ses çıkardığını kanıtlamaz.

Canlı tespitte model puanı bağımsız ses olaylarının aritmetik ortalamasıdır.
Her ek bağımsız tespit ayrıca destek puanı ekler; örtüşen analiz pencereleri
yeniden sayılmaz ve toplam tekrar desteği +20 ile sınırlıdır.

Puan ağırlıklarını **Ayarlar → Algoritma puanları** bölümünden değiştirebilir
ve **Varsayılan puanlara dön** seçeneğiyle sıfırlayabilirsiniz. Güncel formül ve
varsayılan değerler ana README belgesindeki **Puanlama algoritması** bölümünde
yayımlanır.

## Yakınımdaki Kuşlar

Bu ekran genel Türkiye tür listesini değil, bulunduğunuz yer ve mevsime göre
daraltılmış bir saha listesini gösterir.

1. **Yakınımdaki Kuşlar** ekranını açın.
2. **Mevcut konumumu kullan** düğmesine dokunun.
3. İsterseniz tarihi değiştirin; varsayılan tarih bugündür.
4. Uygulama GPS konumunun **20 km yarıçapında** ve seçilen tarihle aynı üç
   aylık mevsimde kaydedilmiş türleri bulur.
5. Türleri fotoğraflarıyla inceleyin:
   - **Yeşil:** Yerel/mevsimsel, normal kayıtlardır.
   - **Kırmızı:** Nadir (`accidental`) sınıfındaki ve bu çevre-mevsim koşulunda
     kaydı bulunan türlerdir.

Mevsimler aralık-ocak-şubat kış, mart-nisan-mayıs ilkbahar,
haziran-temmuz-ağustos yaz ve eylül-ekim-kasım sonbahar olarak değerlendirilir.

Boş liste türün kesinlikle bölgede olmadığı anlamına gelmez. Paket, her
hotspot-tür çifti için son bir yıldaki en yeni onaylı kaydı özetler.

## Hotspot haritası

1. Harita kartını açın veya canlı dinleme ekranındaki harita düğmesine dokunun.
   Kartın tam ekran düğmesi haritayı büyütür; kapatma düğmesi önceki ekrana ve
   boyuta döndürür.
2. Bir gözlem noktasına dokunun.
3. Açılan panelde koordinat, bölge, toplam tür ve son gözlemi inceleyin.
4. **Son kaydedilen kuşlar** listesinde kuş fotoğrafı, Türkçe/bilimsel ad,
   gözlem tarihi ve sayı bulunur.
5. Veri kaynakta mevcutsa gözlemci kimliği de görünür. Canlı eBird API'si bu
   bilgiyi döndürmezse eşleşen çevrimdışı kimlik açıkça
   **EBD gözlemci kimliği** olarak etiketlenir.

### Tür detayında yakın gözlem noktaları

**Yakınımdaki Kuşlar** listesinden bir kuş seçildiğinde Tür Detayı sayfasında
o türe ait yakın gözlem noktaları da gösterilir. Her satırda nokta adı, son
gözlem tarihi, adet, kayıt sayısı ve paylaşılmışsa gözlemci kimliği yer alır.
Satıra dokunmak hotspot haritasını ilgili konuma ortalar. Liste, cihazda saklanan
son 20/50 km eBird indirmesini kullanır; yeni başarılı indirme eski etkin verinin
yerine geçer ve Tür Detayı da güncel veriyi okur.

İndirme düğmesinin yanında örneğin **20 km verisi 30.07.2026 tarihinde
indirildi** bilgisi görünür. Aynı yarıçap seçiliyse düğme **veriyi yenile**
olarak gösterilir. Farklı bir yarıçap seçildiğinde o alan için **veriyi indir**
yazılır. Mevcut tarih kullanıcı için yeterliyse yeniden indirmeden uygulamayı
kullanmaya devam edebilir.

Harita zemini çevrimiçidir. Hotspotlar ve bir yıllık gözlem özeti ise uygulama
paketindedir. Haritadaki ölçek cetveli görünür alanın yaklaşık mesafesini
gösterir. Mavi GPS işaretine, **GPS konumunuz** açıklamasına veya sağ alttaki
konum düğmesine dokunmak haritayı yeniden bulunduğunuz yere ortalar. Arazi
zemini varsayılandır; uydu katmanı lisanslı bir sağlayıcı olmadığı için bu
sürümde etkin değildir.

Sağ üstteki **K** pusulası harita döndürüldüğünde kuzey yönünü göstermeye devam
eder; pusulaya dokunmak haritayı yeniden kuzey yukarı konumuna getirir. Tam ekran
haritada aynı konumdaki küçültme simgesi önceki harita boyutuna döner. Köşe
etiketleri, lejant ve mesafe cetveli açık ve koyu temada aynı yüksek kontrastlı
harita üstü stili kullanır.

## Kişisel eBird API anahtarı

Anahtar zorunlu değildir. Yalnızca hotspotlarda veya yakın çevrede son 30
günlük eBird verisini kullanıcı isteğiyle yenilemek için kullanılır.

1. **Ayarlar** ekranında **eBird canlı veri anahtarı** satırına dokunun.
2. Anahtarınız yoksa **eBird'den kişisel API anahtarı al** düğmesiyle
   <https://ebird.org/api/keygen> sayfasını açın.
3. Kendi anahtarınızı girin ve **Test et ve kaydet** seçeneğine dokunun.
4. Test başarılıysa Ayarlar ekranında yeşil doğrulanmış durum görünür.

Anahtar yalnızca cihazın güvenli deposunda saklanır; uygulama paketine veya
GitHub'a eklenmez.

### Güncel veriyi indirme

- Yakındaki Kuşlar ekranında 20 km veya 50 km seçip **verisini indir**
  düğmesine dokunun.
- Hotspot ayrıntısında **Son verileri eBird'den yenile** seçeneğini kullanın.
- İndirme sırasında durum görünür; tamamlandığında alınan kayıt sayısı yazılır.
- İstek kendiliğinden yapılmaz ve canlı dinlemeyi kesmez.

eBird API'si bazı kayıtlarda gözlemci kimliği döndürmeyebilir. Bu, anahtarın
geçersiz olduğu anlamına gelmez; API yanıtının içerik sınırıdır.

## Ayarlar

| Ayar | Etkisi |
| --- | --- |
| Geçmiş | Analiz ve oturum kayıtlarının geçmişe eklenmesini yönetir. |
| Kırpma modu | Fotoğraftaki kuşun kırpılmasına yönelik yöntemi seçer. |
| Aday gösterme eşiği | Çok düşük güvenli görsel adayları gizler. |
| Canlı tespit minimum güven eşiği | Canlı ses listesinde gösterilecek en düşük skoru belirler. |
| Her ek bağımsız ses tespiti desteği | Aynı türün ayrı ses olaylarında yeniden duyulmasının Kanıt Dosyası'na eklediği puanı belirler. |
| eBird canlı veri anahtarı | Anahtarı test eder, güvenli depoda saklar veya kaldırır. |
| Gözlem bağlamı yarıçapı | Canlı tespitlerde çevrimdışı bölgesel desteğin kapsamını belirler. |
| Tema | Açık, koyu veya sistem temasını seçer. |

## Gizlilik, ağ ve sınırlar

| Özellik | Varsayılan çalışma biçimi |
| --- | --- |
| Fotoğraf/ses tanımlama | Cihaz üzerinde, çevrimdışı |
| Kayıtlar | Cihazın yerel uygulama depolamasında |
| Bir yıllık eBird özeti | Uygulama paketinde, çevrimdışı |
| Harita zemini | Açıldığında çevrimiçi OpenStreetMap katmanı |
| Kuş liste fotoğrafları | Çevrimiçi BirdNET/Cornell görsel adresleri |
| Güncel eBird verisi | Yalnızca kullanıcı indir düğmesine dokunursa |

FirBird bir türün varlığına ya da yokluğuna kesin hüküm vermez. Özellikle nadir
kayıtlarda ayırt edici özellikleri, ses kaydını, konumu ve tarihi birlikte
değerlendirin.

## Sorun giderme

### Yakınımdaki Kuşlar boş görünüyor

- Konum iznini verdiğinizi ve **Mevcut konumumu kullan** düğmesine dokunduğunuzu
  kontrol edin.
- Seçili tarih için 20 km yarıçapta aynı mevsime ait kayıt olmayabilir.
- Ağınız varsa 20 km canlı eBird verisini indirip tekrar deneyin.

### Kuş fotoğrafları görünmüyor

Liste fotoğrafları çevrimiçi kaynaktan gelir. İnternet bağlantısını kontrol
edin. Kaynak fotoğraf isteği başarısızsa uygulama **Fotoğraf alınamadı**
bilgisini gösterir.

### eBird anahtarı doğrulanmıyor

- Anahtarı kopyalarken başta veya sonda boşluk olmadığını kontrol edin.
- Anahtarın kişisel eBird API anahtarı olduğundan emin olun.
- İnternet bağlantısını kontrol edip yeniden deneyin.

### Canlı dinleme başlamıyor

- Mikrofon iznini Android uygulama izinlerinden etkinleştirin.
- Başka bir uygulamanın mikrofonu kullanmadığından emin olun.

## Veri kaynakları

- eBird gözlem bağlamı: [eBird](https://ebird.org/)
- Canlı eBird API anahtarı: <https://ebird.org/api/keygen>
- Harita: OpenStreetMap katkıcıları
- Kuş fotoğrafı adresleri: BirdNET/Cornell taksonomi görsel servisi

eBird verisinin kullanımında eBird veri koşulları geçerlidir.
