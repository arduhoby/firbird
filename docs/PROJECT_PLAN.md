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
