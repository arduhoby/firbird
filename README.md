# FirBird 3

FirBird 3, Türkiye'deki kuş gözlemcileri için geliştirilmiş, Android üzerinde
çalışan **offline-first** bir kuş tanımlama uygulamasıdır. Fotoğraf ve ortam
sesi cihazda analiz edilir; konum ve kayıtlar varsayılan olarak bir sunucuya
gönderilmez.

> Güncel sürüm: **v0.6.5 (build 71)**

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
- **Canlı eBird güncellemesi:** Kendi kişisel API anahtarınızla, yalnızca siz
  istediğinizde 20 veya 50 km çevreden son 30 günlük hotspot kayıtları
  indirilebilir. Bu işlem canlı dinlemeyi kesmez.

## v0.6.5 yenilikleri

- Yakındaki kuşlar ve hotspot kayıtlarına kuş fotoğrafları eklendi.
- Yakın tür listesi genel Türkiye listesinden GPS'e göre 20 km çevre ve aynı
  mevsim kayıtlarına daraltıldı.
- Yerel/mevsimsel türler ve nadir türler yeşil/kırmızı bölümlerde ayrıldı.
- Bir yıllık Türkiye eBird bağlam paketi uygulamaya dahil edildi.
- Kişisel eBird API anahtarı için test, güvenli saklama ve yeşil doğrulama
  durumu eklendi.

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
