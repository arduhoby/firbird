# FirBird Project Plan

FirBird is an offline-first, open-source bird identification application. The Android MVP starts with Türkiye and supports Android 9 (API 28) and later.

## Delivery order

1. Foundation: Flutter app, localization, navigation, quality controls, licensing, and Android build.
2. Photo selection and EXIF metadata, followed by user-controlled location and date context.
3. Deterministic mock inference, results, species detail, and local identification history.
4. Secure regional-package installation and contextual reranking.
5. TFLite validation, performance hardening, and Android MVP release.
6. Licensed data/model pipeline, Balkans package, and iOS support.

No photo, EXIF field, or location is sent from the device during identification.

## Planlanan kamera kısayolu

Fotoğraf seçim ekranında `Fotoğraf seç` düğmesinin yanına küçük bir kamera simgesi eklenecektir. Kullanıcı bu simgeye dokunarak anında fotoğraf çekebilecek; çekilen fotoğraf doğrudan mevcut tanımlama akışına aktarılacaktır. Kamera izni yalnızca ilk kullanımda istenir ve fotoğraf cihaz dışına gönderilmez.

## GitHub indirilebilir dosya planı

Kaynak kod ile büyük, sürümlü indirilebilir içerikler ayrı tutulur. Kaynak kod normal Git geçmişinde kalır; uygulama, model ve bölge paketleri yalnızca GitHub Releases varlığı olarak yayımlanır.

Her yayın için hedef yapı:

```text
FirBird v0.x.y (GitHub Release)
├── firbird-v0.x.y-android.apk
├── firbird-v0.x.y-android.aab
├── firbird-catalog-v1.json
├── SHA256SUMS.txt
└── RELEASE_NOTES.md

FirBird data v0.x.y (GitHub Release)
├── turkey-all-v0.x.y.firbird
├── balkans-v0.x.y.firbird
├── bioclip2-int8-v0.x.y.onnx
├── bioclip2-candidates-turkey-v0.x.y.firbird
├── bioclip2-candidates-balkans-v0.x.y.firbird
├── firbird-catalog-v1.json
├── SHA256SUMS.txt
├── attribution.zip
└── licenses.zip
```

`firbird-catalog-v1.json`, uygulamanın paket ekranında gösterilecek sürümü, boyutu, SHA-256 özeti, indirme bağlantısı, model uyumluluğu ve lisans bilgisini taşır. Uygulama indirirken geçici dosya kullanır, SHA-256 doğrular ve yalnızca kontrol başarılıysa paketi etkinleştirir.

Türkiye ve Balkanlar paketleri ayrı indirilir. İkisi de kuruluysa ortak türler tekrarlanmaz; sonuçta türün `Türkiye`, `Balkanlar` veya `Türkiye ve Balkanlar · ortak` kapsamından geldiği gösterilir.

## Yakınımdaki kuşlar

Uygulama, BirdNET benzeri bir `Yakınımdaki kuşlar` keşif ekranı sunacaktır. Bu ekran tanımlama yapmadan, kullanıcının seçtiği yaklaşık konum ve tarihe göre o çevrede görülmesi beklenen türleri listeler.

- Konum kullanımı isteğe bağlıdır; kullanıcı mevcut konumunu, haritadan yaklaşık bir noktayı veya bölge listesini seçebilir.
- Kesin koordinat sunucuya gönderilmez ve varsayılan olarak kalıcı saklanmaz. Koordinat, cihazda bölge/grid kimliğine dönüştürülür.
- Sonuçlar seçili bölge paketi ile tarih/mevsim öncüllerine göre sıralanır.
- Her tür kartında Türkçe ad, bilimsel ad, küçük görsel, görülme durumu ve köken etiketi gösterilir.
- Kullanıcı tür kartından Trakuş ve Ornito.org’daki tür sayfasını açabilir.
- Konum veya tarih bilinmiyorsa, paket kapsamındaki türler filtrelenmeden ancak uygun bir bilgilendirme ile listelenir.
- İnternet, yalnızca dış kaynak bağlantılarını açmak için gerekir; kurulu paketlerin listesi çevrimdışı çalışır.
