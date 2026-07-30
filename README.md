# FirBird 3

FirBird 3, Türkiye'deki kuş gözlemcileri için geliştirilmiş, Android üzerinde
çalışan **offline-first** bir kuş tanımlama uygulamasıdır. Fotoğraf ve ortam
sesi cihazda analiz edilir; konum ve kayıtlar varsayılan olarak bir sunucuya
gönderilmez.

> Güncel sürüm: **v0.8.1 (build 81)**

Tanımlamalar birer öneridir. Özellikle nadir tür kayıtlarını saha notu,
fotoğraf/ses ve güvenilir gözlem kaynaklarıyla doğrulayın.

## Hızlı başlangıç

1. Uygulamayı açın ve gerekirse fotoğraf, mikrofon ve konum izinlerini verin.
2. Bir kuş fotoğrafını **Fotoğraftan Tanımla** ile seçin veya ortam sesini
   **Canlı Ses Tespiti** ile dinleyin.
3. Önerilen türün fotoğrafına, Türkçe/bilimsel adına ve güven bilgisine bakın.
4. Yakın çevredeki kayıtları görmek için **Yakınımdaki Kuşlar** ekranında
   **Mevcut konumumu kullan** seçeneğine dokunun.
5. Son eBird kayıtlarını yenilemek isterseniz kendi API anahtarınızı Ayarlar'da
   doğrulayın; ardından 20 veya 50 km verisini isteğe bağlı olarak indirin.

Ekran ekran ayrıntılı açıklama için [Kullanım Kılavuzu](docs/KULLANIM_KILAVUZU.md)
belgesine bakın.

## Öne çıkan özellikler

- **Fotoğraftan tanımlama:** Galeriden seçilen veya kamerayla çekilen kuş
  fotoğrafı cihaz üzerinde analiz edilir. EXIF tarih ve GPS bilgisi varsa
  bağlam değerlendirmesinde kullanılabilir.
- **Canlı ses tespiti:** BirdNET tabanlı model mikrofon akışını sürekli analiz
  eder. Kayıt kesintisiz sürer ve tespitler zaman damgasıyla görünür.
- **Kayıt ve oynatıcı:** Canlı oturum WAV olarak saklanır. Oturum sonunda süre
  çubuğu, oynat/durdur, ses seviyesi ve tespit anına atlama seçenekleriyle
  tekrar dinlenebilir.
- **Kullanıcı geri bildirimi:** Canlı ses adayları **Doğru** veya **Doğru
  değil** olarak işaretlenebilir; kartı sağa kaydırmak doğrulama akışını açar.
- **Yakındaki kuşlar:** GPS konumunun 20 km yarıçapında, seçilen tarihle aynı
  mevsimde gözlenmiş türler listelenir. Yerel/mevsimsel kayıtlar yeşil, nadir
  kayıtlar kırmızı grupta gösterilir.
- **Hotspot haritası:** eBird gözlem noktasına dokunarak noktadaki son tür
  kayıtlarını, tarihi, sayıyı ve veri varsa gözlemci kimliğini görebilirsiniz.
  Tür listelerinde kuş fotoğrafları kullanılır.
- **Tür detayında yakın kayıtlar:** Yakınımdaki Kuşlar listesinden açılan Tür
  Detayı, seçilen türün mevcut 20/50 km alanındaki gözlem noktalarını; tarih,
  adet ve varsa gözlemci kimliğiyle listeler. Noktaya dokunmak aynı hotspot
  haritasını o konumda açar.
- **İndirme durumu:** eBird indirme düğmesinin yanında cihazda saklanan etkin
  verinin yarıçapı ve indirilme tarihi gösterilir. Aynı yarıçap seçildiğinde
  düğme yenileme davranışına geçer; kullanıcı mevcut veri yeterliyse indirmeden
  devam edebilir.
- **Canlı eBird güncellemesi:** Kendi kişisel API anahtarınızla, yalnızca siz
  istediğinizde 20 veya 50 km çevreden son 30 günlük hotspot kayıtları
  indirilebilir. Bu işlem canlı dinlemeyi kesmez.

## v0.8.0 — Açıklanabilir Kanıt Sistemi

v0.8.0 ile canlı dinleme, ses dosyası analizi ve geçmiş/replay kayıtları aynı
`DetectionRecord` veri sözleşmesini, aynı kuş tespit kartını ve aynı **Kanıt
Dosyası** görünümünü kullanır. Bir karta dokunulduğunda uygulama yalnızca bir
yüzde göstermek yerine sonucu destekleyen, zayıflatan ve değerlendirilemeyen
bilgileri ayrı ayrı açıklar.

Kanıt Dosyası şu kaynakları birlikte değerlendirir:

- Cihaz içi ses modelinin ham benzerlik puanı.
- Tespit saati, konumdaki güneş evresi ve türün gündüz/gece etkinlik profili.
- Kullanıcının indirdiği 20 veya 50 km eBird çevre verisindeki aynı türe ait
  yakın, benzer saatli ve aynı mevsimli kayıtlar.
- Bu cihazda kullanıcının daha önce **Doğru** veya **Doğru değil** olarak
  işaretlediği tespitler.
- Kullanılamayan konum, indirilmemiş eBird verisi veya bilinmeyen etkinlik
  profili gibi veri boşlukları.

### eBird verisi doğruluğu nasıl geliştirir?

eBird güncellemesi otomatik yapılmaz. Kullanıcı 20 veya 50 km verisini
indirdiğinde sorgunun merkezi, yarıçapı, indirme zamanı ve gözlemler cihazda
saklanır. Uygulama yeniden açıldığında son başarılı indirme geri yüklenir;
yeniden indirme başarılı olursa önceki aktif çevre görüntüsü yenisiyle
değiştirilir.

Daha güncel çevre verisi; yakınlarda aynı türün hangi tarihlerde, mevsimlerde
ve günün hangi saatlerinde görüldüğünü Kanıt Dosyası'na taşır. Bu nedenle
kullanıcılar eBird'den son bilgileri indirdikçe bağlamsal değerlendirme daha
güncel hale gelir. Ancak bir eBird gözlemi kuşun o anda **ses çıkardığını**
kanıtlamaz; yalnızca o zaman ve yerde varlık kaydı bulunduğunu gösterir. Kayıt
bulunmaması da türün bölgede bulunmadığının kanıtı değildir.

### Puanlama algoritması

Algoritma sürümü: `evidence-v1`

```text
sonuç puanı = sınırla(model puanı + bağlam puanları, 0, 100)
model puanı = yuvarla(model güveni × 100)
```

Varsayılan değerler **Ayarlar → Algoritma puanları** bölümünden kullanıcı
tarafından değiştirilebilir ve tek düğmeyle varsayılanlara döndürülebilir.

| Kanıt | Varsayılan | Uygulama kuralı |
| --- | ---: | --- |
| Saat uyumsuzluğu | −30 | Türün etkinlik profili ile güneş evresi güçlü biçimde çelişirse tam, kısmen çelişirse yarım ceza. |
| Yakında aynı saat desteği | +30 | 20/50 km çevrede ±2 saat aralığında iki veya daha fazla kayıt varsa tam, bir kayıt varsa yarım destek. |
| Mevsim uyumu | +10 | Yakın çevrede aynı mevsime ait en az bir kayıt varsa uygulanır. |
| Cihazda doğrulanmış tür | +15 | Doğru sayısı yanlış sayısından fazlaysa uygulanır. |
| Cihazda reddedilmiş tür | −25 | Yanlış sayısı doğru sayısından fazlaysa uygulanır. |

Puanlar gerçeğin yerine geçmez. Amaç, model tahminini neden desteklediğimizi
veya neden şüpheyle karşılamamız gerektiğini kullanıcıya denetlenebilir biçimde
göstermektir. Bütün kanıt satırlarında kullanılan veri kaynağı ayrıca yazılır.

### Ortak kart ve Kanıt Dosyası

- Canlı dinleme, ses dosyası ve replay aynı `BirdDetectionCard` bileşenini
  kullanır.
- Kartın tamamına dokunmak Kanıt Dosyası'nı açar.
- Replay kartındaki ayrı oynat düğmesi doğrudan tespit anına gider.
- **Doğru / Doğru değil** değerlendirmeleri cihazda kalıcı tutulur ve sonraki
  tespitlerde cihaz geçmişi kanıtına dönüşür.
- Kuş adı, fotoğrafı, bilimsel adı, saat, kaynak ve puan her giriş noktasında
  aynı düzende gösterilir.

### Ekran görüntüsü yerleşim planı

Ekran görüntüleri eklendiğinde aşağıdaki dosya adları kullanılacaktır:

| Bölüm | Önerilen dosya |
| --- | --- |
| Canlı ortak tespit kartı | `assets/screenshot/v0.8.0-live-detection-card.jpg` |
| Ses dosyası sonuç kartları | `assets/screenshot/v0.8.0-audio-file-results.jpg` |
| Açıklanabilir Kanıt Dosyası | `assets/screenshot/v0.8.0-evidence-sheet.jpg` |
| Algoritma puan ayarları | `assets/screenshot/v0.8.0-algorithm-settings.jpg` |
| Tam ekran hotspot haritası | `assets/screenshot/v0.8.0-fullscreen-map.jpg` |

Dosyalar eklendikten sonra bu tablo gerçek görseller ve kısa ekran açıklamaları
ile değiştirilecektir.

## Sürüm geçmişi

FirBird'in sürüm numaraları yalnızca arayüz değişikliklerini değil; model,
çevrimdışı veri, ses kaydı, harita ve doğrulama mimarisindeki kilometre
taşlarını da gösterir. Git etiketi bulunmayan bazı numaralar geliştirme sırasında
kullanılmış ara sürümlerdir.

| Sürüm | Başlıca değişiklikler |
| --- | --- |
| `v0.0.1–v0.0.2` | İlk Flutter/Android uygulaması, temel fotoğraf tanımlama akışı, geçmişin otomatik kaydı ve Yakınımdaki Kuşlar ekranının ilk hali. |
| `v0.1.x` | Türkiye çevrimdışı bölge paketi, Balkan paketleme/veri politikası hazırlıkları ve GitHub paket yerleşimi. |
| `v0.2.1` | Ses dosyası seçimi, BirdNET ses tanımlama, model indirme ve kullanıcı düzeltmeleri. |
| `v0.2.2` | Görsel ve ses modellerinin uygulamayla gelmesi; Türkçe tür adları, görülme durumu ve cinsiyet/yaşam evresi politikasının ilk sürümü. |
| `v0.2.3` | 503 tür veri kümesi ve karakter kodlama onarımları. |
| `v0.2.4` | Aynı oturumda birden fazla türü izleyen canlı biyoakustik araştırma modu. |
| `v0.2.5` | Canlı WAV akışı, desibel ölçümü ve ekolayzır görselleştirmesi. |
| `v0.3.0` | Canlı Ses Tespiti ekranı, tespit geçmişi, minimum güven eşiği ve yeni tespitleri öne alan sıralama. |
| `v0.3.1` | Yan menü ve geçmişte canlı oturumları tek özet kartından açma. |
| `v0.3.2` | Açık/koyu/sistem teması, konum izni, durum renkleri, uygulama logosu ve Android simgeleri. |
| `v0.4.0` | Genel arayüz modernizasyonu, görsel kullanılabilirlik düzenlemeleri ve doğrulanmış ARM64 GitHub sürümü. |
| `v0.4.1` | Canlı oturum kayıtları ile geçmiş kayıtlarını ortak oynatıcıya taşıyan ilk birleşim. |
| `v0.5.1` | Canlı ses hassasiyeti, bölgesel/zamansal aday politikası ve çevrimdışı eBird bağlamının ilk sürümü. |
| `v0.6.1–v0.6.4` | Harita ve replay yenilemesi; hotspot tür/gözlemci listeleri; GPS merkezli yakınlaştırma; Türkçe adlar; kişisel eBird API anahtarı testi ve indirme arayüzü. |
| `v0.6.5` | Bir yıllık Türkiye eBird paketi, kuş fotoğrafları ve 20 km/mevsim tabanlı yerel–nadir tür ayrımı. |
| `v0.7.0` | Tek oynatıcı, tek kuş kataloğu ve tek fotoğraf bileşeniyle kod bütünlüğü mimarisi. |
| `v0.7.1` | Mikrofonla kontrollü canlı başlangıç, kesintisiz harita erişimi, tam ekran harita, GPS/ölçek düzeni ve kompakt Ayarlar formu. |
| `v0.8.0` | Açıklanabilir Kanıt Dosyası, değiştirilebilir puanlama, kalıcı eBird çevre verisi ve cihaz doğrulama hafızası. |
| `v0.8.1` | İndirme yarıçapı/tarihi durumu, yenileme davranışı, yüksek kontrastlı harita kaplamaları, küçültme düğmesi ve kuzey pusulası. |

### v0.8.1

- eBird indirme düğmesinin yanında kalıcı yarıçap ve indirilme tarihi bilgisi.
- Kayıtlı yarıçap seçildiğinde **veriyi yenile**, farklı yarıçap seçildiğinde
  **veriyi indir** davranışı.
- Koyu temada da yüksek kontrastlı harita etiketleri ve mesafe cetveli.
- Tam ekranda haritayı küçültme düğmesi ve döndürmeye duyarlı kuzey pusulası.

### v0.8.0

- Açıklanabilir, puan dökümlü Kanıt Dosyası.
- Canlı, ses dosyası ve replay için ortak kuş tespit kartı.
- Kalıcı eBird çevre verisi ve kalıcı cihaz doğrulama hafızası.
- Kullanıcı tarafından değiştirilebilir Algoritma puanları.
- Harita yüzeyinde tam ekran kontrolü ve belirgin Ayarlar kategorileri.
- Tür Detayı sayfasında seçilen kuşa ait yakın eBird gözlem noktaları.

### v0.7.1

- Canlı ses ekranı artık kendiliğinden dinlemeye başlamaz. Model hazırlandıktan
  sonra kullanıcı mikrofon düğmesine dokunur; mikrofon ve konum izinleri o anda
  istenir.
- Hotspot haritası aynı bileşenle kart veya tam ekran açılır ve tek dokunuşla
  önceki boyutuna döner. Canlı dinleme sırasında açıldığında kayıt kesilmez.
- GPS işareti ve **GPS konumunuz** açıklaması haritayı yeniden konuma ortalar.
- Mesafe ölçeği, görünür alan ve 20/50 km yarıçap etiketleri ayrı köşelere
  sabitlendi; yakınlaştırmaya göre görünür alan değeri güncellenir.
- Hotspot gözlem listesine iOS'ta da görünen kapatma düğmesi eklendi.
- Düğmeler, açılır seçimler ve Ayarlar ekranı daha kompakt, form düzenli ve dar
  ekranlarda metni kesmeyecek biçimde düzenlendi.
- Lisanslı uydu sağlayıcısı gerektirmeyen mevcut OpenStreetMap arazi zemini
  varsayılan ve tek harita katmanı olarak korundu.

### v0.7.0

- **Kod bütünlüğü:** Canlı oturum, geçmiş kayıt ve doğrudan açılan sesler tek
  oynatma sözleşmesi, tek controller ve tek player ekranında birleştirildi;
  kuş kataloğu ile fotoğraf gösterimi de uygulama genelinde ortaklaştırıldı.

### v0.6.5

- Yakındaki kuşlar ve hotspot kayıtlarına kuş fotoğrafları eklendi.
- Yakın tür listesi genel Türkiye listesinden GPS'e göre 20 km çevre ve aynı
  mevsim kayıtlarına daraltıldı.
- Yerel/mevsimsel türler ve nadir türler yeşil/kırmızı bölümlerde ayrıldı.
- Bir yıllık Türkiye eBird bağlam paketi uygulamaya dahil edildi.
- Kişisel eBird API anahtarı için test, güvenli saklama ve yeşil doğrulama
  durumu eklendi.

## Gelecek yol haritası

Yol haritası kesin tarih veya özellik taahhüdü değildir. Sıralama; saha
testleri, veri kalitesi, lisans koşulları ve cihaz üzerindeki performansa göre
değişebilir.

### Yakın plan

- **Kanıt algoritması v2:** Tür bazlı gündüz/gece etkinlik profillerini
  genişletmek ve mevcut puanları gerçek saha doğrulamalarıyla kalibre etmek.
- **Veri tazeliği:** Kanıt Dosyası'nda kullanılan eBird paketinin yaşı,
  yarıçapı ve kayıt kapsamını daha görünür hale getirmek; eski veriyi açıkça
  uyarmak.
- **Doğrulama geçmişi:** Kullanıcının cihazdaki Doğru/Doğru değil kararlarını
  tür bazında özetlemek ve algoritmaya ne kadar katkı yaptığını göstermek.
- **Kanıt ayrıntıları:** Aynı türün yakın çevredeki saat dağılımını, tekrar
  sayısını ve gözlem noktalarını tek kanıt zincirinde daha ayrıntılı sunmak.
- **Belgeleme:** Kullanıcının sağlayacağı gerçek ekran görüntüleriyle README ve
  kullanım kılavuzunu ekran ekran, Wikipedia benzeri bir başvuru kaynağına
  dönüştürmek.

### Araştırma ve sonraki aşamalar

- **Yeni bağlam kaynakları:** Lisansı ve veri kalitesi uygun olduğunda habitat,
  göç dönemi ve hava koşulu gibi ek kanıtları puanlamaya kontrollü biçimde
  dahil etmek.
- **Tür bazlı görsel özellikler:** Yalnız güvenilir veri bulunan türlerde gerçek
  bir cinsiyet/yaşam evresi modeli kullanmak; diğer durumlarda sonucu
  **Belirsiz** bırakmak.
- **Yerel öğrenme ve kalibrasyon:** Kullanıcının doğruladığı kayıtlarla cihaz
  üzerinde güven eşiklerini kişiselleştirmek; ham kullanıcı verisini izinsiz
  olarak dışarı göndermemek.
- **Paket güncelleme süreci:** Türkiye eBird çevrimdışı paketini yeni veri
  dönemleriyle tekrarlanabilir ve denetlenebilir biçimde yenilemek.

### Değişmeyecek ilkeler

- Tanımlama ve puanlama mümkün olduğunca cihazda çalışır.
- eBird indirmeleri yalnız kullanıcının açık işlemiyle yapılır.
- Kişisel API anahtarı APK'ya, README'ye veya gözlem önbelleğine yazılmaz.
- Puan, gözlem veya model sonucu kesin teşhis gibi sunulmaz; kullanılan her
  kanıtın kaynağı ve sınırlaması açıklanır.

## Türkiye eBird bağlam paketi

Uygulama, eBird Basic Dataset'ten türetilen çevrimdışı Türkiye paketini içerir.
Paket, onaylanmış hotspot gözlemlerinden her hotspot ve tür için en güncel
kaydı özetler; kapsadığı dönem **365 gün**dür.

| Kapsam | Değer |
| --- | --- |
| Ülke | Türkiye, 81 il |
| Hotspot | 4.857 |
| Hotspot-tür özeti | 93.637 |
| Paket sürümü | `2026.07.29-ebd1y` |

Bu veriler bir türün kesin bulunurluğunu kanıtlamaz. Yakın kaydın olmaması da
türün bölgede bulunmadığı anlamına gelmez. Canlı eBird API anahtarı APK'ya
eklenmez; her kullanıcı isterse kendi anahtarını girer.

## Gizlilik ve ağ kullanımı

| İşlem | İnternet gerekir mi? | Nerede çalışır? |
| --- | --- | --- |
| Fotoğraftan tanımlama | Hayır | Cihazda |
| Canlı ses tespiti ve kayıt | Hayır | Cihazda |
| Geçmiş kayıtların oynatılması | Hayır | Cihazda |
| Bir yıllık eBird bağlamı | Hayır | APK içindeki paket |
| Harita zemini | Evet | OpenStreetMap katmanı |
| Kuş liste fotoğrafları | Evet | BirdNET/Cornell görsel kaynağı |
| Son 30 günlük eBird verisi | Evet, yalnızca kullanıcı isterse | Kişisel API anahtarıyla eBird |

Kişisel eBird API anahtarı yalnızca cihazın güvenli deposunda saklanır. Canlı
dinleme kendiliğinden eBird'e istek atmaz.

## İzinler

- **Kamera:** Yeni kuş fotoğrafı çekmek için.
- **Fotoğraf/medya:** Galeriden fotoğraf veya ses dosyası seçmek için.
- **Mikrofon:** Canlı ses tespiti ve kayıt için.
- **Konum:** Yakındaki türleri, hotspotları ve bölgesel bağlamı GPS'e göre
  hesaplamak için. Konum verilmezse temel tanımlama yine çalışır.
- **İnternet:** Harita zemini, kuş fotoğrafları ve kullanıcı isteğiyle canlı
  eBird güncellemesi için.

## Geliştirme ve derleme

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
```

ARM64 Android cihazlar için APK çıktısı:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Veri kaynakları ve lisans

- Gözlem bağlamı: [eBird](https://ebird.org/); eBird veri koşulları geçerlidir.
- Kuş fotoğrafı adresleri: BirdNET/Cornell taksonomi görsel servisi.
- Harita zemini: OpenStreetMap katkıcıları.
- Kaynak kod: [Apache License 2.0](LICENSE).
