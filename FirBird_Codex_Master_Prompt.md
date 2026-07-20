# FirBird — Codex Ana Geliştirme Dosyası

Bu dosya, FirBird projesi için ürün kararlarını, teknik mimariyi, lisans yaklaşımını, geliştirme fazlarını ve ChatGPT Codex'e verilecek ana uygulama promptunu tek yerde toplar.

Bu dosyanın tamamını Codex'e tek seferde ver ve repository üzerinde baştan sona uygulamasını iste.

---

# 1. Projenin özeti

**FirBird**, tamamen açık kaynaklı, cihaz üzerinde çalışan ve internet bağlantısı olmadan kuş tanımlayabilen bir mobil uygulamadır.

Uygulama ilk olarak Android için geliştirilecektir.

Temel hedefler:

- Android 9 ve üzeri
- Fotoğraftan kuş tanıma
- Tamamen cihaz üzerinde inference
- Türkiye'nin tamamını kapsayan ilk bölge paketi
- Sonradan Balkanlar ve başka bölgelerin eklenebilmesi
- Harita uygulamalarındaki offline paket mantığı
- Konum ve tarih bilgisiyle sonuçların yeniden sıralanması
- GitHub üzerinden açık kaynak geliştirme
- Daha sonra iOS desteği
- Kullanıcı katkılarıyla veri ve model geliştirme

---

# 2. Kesinleşmiş ürün kararları

Aşağıdaki kararlar kesindir:

```text
Uygulama adı: FirBird
Kaynak kod: Tamamen açık kaynak
Kod lisansı: Apache License 2.0
Ticari kullanım: Serbest
Değiştirme ve yeniden dağıtım: Serbest
İlk platform: Android
Minimum Android: Android 9
Minimum API: 28
İkinci platform: iOS
İlk bölge: Türkiye'nin tamamı
İkinci bölge: Balkanlar
İlk giriş türü: Yalnızca mevcut fotoğraf
Kamera: İlk sürümde yok
Canlı kamera analizi: İlk sürümde yok
Ses tanıma: İlk sürümde yok
Başlangıç repository'si: Yok
Paket dağıtımı: GitHub Releases
İlk model: Henüz yok
İlk mobil geliştirme yaklaşımı: Flutter
```

---

# 3. Codex için ana rol tanımı

Sen kıdemli bir:

- Flutter geliştiricisi
- Android mühendisi
- iOS mühendisi
- Cihaz üzerinde makine öğrenmesi uzmanı
- Veri mühendisi
- Açık kaynak proje yöneticisi
- Mobil güvenlik mühendisi
- Yazılım mimarı

olarak çalışacaksın.

Görevin, **FirBird** isimli açık kaynak kuş tanımlama uygulamasını sıfırdan geliştirmektir.

Projeyi yalnızca planlama, açıklama veya örnek kod düzeyinde bırakma.

Gerçek repository oluştur.

Gerçek dosyaları yaz.

Build al.

Testleri çalıştır.

Hataları düzelt.

Tamamlanan fazdan sonra bir sonraki mantıklı faza devam et.

Gereksiz onay isteme.

Geri alınabilir teknik kararlarda makul varsayımlar yap.

Önemli kararları `docs/decisions/` altında ADR olarak kaydet.

Yalnızca şu durumlarda kullanıcıdan bilgi iste:

- Gizli anahtar gerekiyorsa
- Kod imzalama sertifikası gerekiyorsa
- Veri veya model lisansı belirsizse
- Geri döndürülemez dış işlem yapılacaksa
- Ücretli servis açılması gerekiyorsa
- Kullanıcı hesabına erişim gerekiyorsa

Bunların dışında ilerlemeye devam et.

---

# 4. Teknoloji kararı

Uygulamayı öncelikle Flutter ile geliştir.

Varsayılan teknoloji seti:

```text
Framework: Flutter
Language: Dart
Android minimum SDK: 28
State management: Riverpod
Navigation: go_router
Database: Drift + SQLite
Networking: Dio
Serialization: json_serializable
Immutable models: freezed
Image selection: image_picker
Map: flutter_map
Map data: OpenStreetMap tabanlı
Location: geolocator
Checksums: SHA-256
Testing: flutter_test, integration_test, mocktail
Static analysis: flutter_lints ve sıkı lint kuralları
```

Harita için ücretli veya API anahtarı gerektiren servisleri zorunlu yapma.

İlk tercih:

```text
flutter_map + OpenStreetMap
```

Harita tile kullanım şartlarını dokümante et.

OSM tile sunucularından izinsiz toplu offline tile indirme yapma.

İlk MVP'de harita çevrimiçi görüntülenebilir.

Ancak tanımlama ve daha önce indirilmiş kuş paketleri tamamen çevrimdışı çalışmalıdır.

---

# 5. Flutter ve native sınırı

Flutter kullanıcı arayüzü ve iş akışını yönetsin.

Ağır işlemleri Dart UI isolate'ında çalıştırma:

- Büyük görsel decode
- Görsel yeniden boyutlandırma
- Model inference
- Büyük checksum hesaplama
- Büyük arşiv açma
- Embedding karşılaştırması
- Büyük aday tür listesi sıralama

Sırasıyla şu seçenekleri değerlendir:

1. Dart isolate
2. FFI
3. Platform channel
4. Android Kotlin native plugin
5. iOS Swift native plugin

Ölçüm yapmadan gereksiz native kod yazma.

Ancak inference katmanını baştan soyutla.

```dart
abstract interface class BirdInferenceEngine {
  Future<InferenceResult> identify(
    ImageInput image,
    IdentificationContext context,
  );

  Future<void> warmUp();

  Future<ModelInformation> getModelInformation();

  Future<void> dispose();
}
```

Planlanan implementasyonlar:

```text
MockBirdInferenceEngine
TfliteBirdInferenceEngine
OnnxBirdInferenceEngine
NativeAndroidBirdInferenceEngine
CoreMlBirdInferenceEngine
```

Aşağıdaki koşullarda yalnızca inference katmanını Android Kotlin'e taşı:

- Flutter plugin istikrarsızsa
- Bellek kullanımı kabul edilemezse
- Görüntü kopyalama ciddi gecikme oluşturursa
- Orta seviye Android cihazda hedef süre sağlanamazsa
- Donanım hızlandırma kullanılamıyorsa

Tüm uygulamayı native Kotlin'e taşımadan önce sadece darboğaz oluşturan katmanı native hale getir.

React Native kullanma.

---

# 6. Kullanıcı deneyimi

Temel tanımlama akışı:

1. Kullanıcı galeriden bir kuş fotoğrafı seçer.
2. Uygulama EXIF orientation bilgisini işler.
3. Uygulama EXIF tarih ve GPS bilgisini okur.
4. Kullanıcı fotoğrafın bölgesini belirler.
5. Kullanıcı fotoğrafın tarihini belirler.
6. Model cihaz üzerinde çalışır.
7. Aktif bölge paketindeki türler değerlendirilir.
8. Konum ve mevsimsel öncüller sonuçları yeniden sıralar.
9. Kullanıcıya en olası türler gösterilir.
10. Hiçbir fotoğraf veya konum verisi sunucuya gönderilmez.

---

# 7. Konum seçenekleri

Kullanıcı konum vermek zorunda değildir.

Tanımlama ekranında şu seçenekleri sun:

```text
Fotoğraf konumunu belirle

○ Fotoğrafın EXIF konumunu kullan
○ Haritadan seç
○ Mevcut konumumu kullan
○ Bölge listesinden seç
○ Konumu bilmiyorum
```

## EXIF konumu

Fotoğraf EXIF GPS bilgisi taşıyorsa:

- Kullanıcıya bulunduğunu bildir
- Açık onay olmadan otomatik kullanma
- Kesin koordinatı gereksiz yere saklama
- Konumu coğrafi grid veya bölge ID'sine dönüştürmeyi tercih et

## Haritadan seçim

Kullanıcı harita üzerinde yaklaşık konum seçebilsin.

Seçilen nokta aşağıdaki alanlara dönüştürülebilsin:

```text
countryCode
administrativeRegion
birdRegionId
geographicGridId
```

## Mevcut konum

Cihaz konumu yalnızca kullanıcı bu seçeneği seçtiğinde istenmelidir.

İzin reddedildiğinde uygulama çalışmaya devam etmelidir.

## Konum bilinmiyor

Bu durumda yalnızca görsel skorlar ve varsa tarih bilgisi kullanılmalıdır.

---

# 8. Tarih seçenekleri

Kullanıcı fotoğrafın çekildiği tarihi belirleyebilsin.

```text
○ Fotoğraf bilgisindeki tarihi kullan
○ Tarihi elle seç
○ Bugünün tarihini kullan
○ Tarihi bilmiyorum
```

Galeriden seçilen eski bir fotoğraf için cihazın bugünkü tarihini otomatik varsayma.

EXIF tarihi varsa kullanıcıya öner ancak onaylat.

---

# 9. İlk bölge paketi

İlk paket Türkiye'nin tamamını kapsamalıdır.

```text
Package ID: turkey-all
Display name: Türkiye — Tüm Bölgeler
Coverage: Türkiye'nin tamamı
```

İkinci paket:

```text
Package ID: balkans
Display name: Balkanlar
```

Paket sistemi başka ülke ve bölgelerin eklenmesine uygun olmalıdır.

---

# 10. Bölge paketi formatı

Önerilen paket:

```text
turkey-all-v1.0.0.firbird
├── manifest.json
├── species.sqlite
├── species_ids.bin
├── geographic_priors.bin
├── seasonal_priors.bin
├── habitat_priors.bin
├── visual_prototypes.bin
├── thumbnails/
├── content/
│   ├── tr/
│   └── en/
├── attribution/
└── licenses/
```

`.firbird` dosyası güvenli biçimde açılan bir arşiv olabilir.

Örnek manifest:

```json
{
  "schemaVersion": 1,
  "packageId": "turkey-all",
  "displayName": {
    "tr": "Türkiye — Tüm Bölgeler",
    "en": "Türkiye — All Regions"
  },
  "version": "1.0.0",
  "taxonomyVersion": "1",
  "coverage": {
    "countryCodes": ["TR"]
  },
  "speciesCount": 0,
  "downloadSizeBytes": 0,
  "installedSizeBytes": 0,
  "minimumAppVersion": "0.1.0",
  "modelCompatibility": {
    "encoderId": "firbird-visual-v1",
    "embeddingDimension": 512
  },
  "files": [],
  "licenses": []
}
```

---

# 11. GitHub repository yapısı

Başlangıçta tek repository ile başla:

```text
firbird/
├── apps/
│   └── mobile/
├── packages/
│   ├── app_core/
│   ├── design_system/
│   ├── inference/
│   ├── region_packages/
│   ├── species_data/
│   └── location_context/
├── tools/
│   ├── package_builder/
│   ├── catalog_builder/
│   ├── model_tools/
│   └── sample_data_generator/
├── sample_data/
├── docs/
│   ├── architecture/
│   ├── decisions/
│   ├── model/
│   ├── data/
│   ├── labeling/
│   ├── privacy/
│   └── package_format/
├── .github/
│   └── workflows/
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
├── SECURITY.md
├── TRADEMARKS.md
├── THIRD_PARTY_NOTICES.md
├── NOTICE
├── LICENSE
└── README.md
```

İlk aşamada monorepo gereksiz karmaşıklık oluşturursa daha sade yapı kur ve bunu ADR olarak belge.

İleride gerekirse üç repository ayrımı yapılabilir:

```text
firbird-app
firbird-data
firbird-labeling
```

---

# 12. GitHub Releases dağıtımı

Büyük dosyaları normal Git geçmişine ekleme.

GitHub Releases üzerinden yayımla:

- Android APK
- Android App Bundle
- Türkiye bölge paketi
- Balkanlar bölge paketi
- Model dosyaları
- Checksum dosyaları
- Katalog JSON dosyası

Örnek katalog:

```json
{
  "schemaVersion": 1,
  "generatedAt": "ISO-8601",
  "packages": [
    {
      "id": "turkey-all",
      "version": "1.0.0",
      "downloadUrl": "GitHub Release asset URL",
      "sha256": "",
      "sizeBytes": 0
    }
  ],
  "models": [
    {
      "id": "firbird-visual-v1",
      "version": "1.0.0",
      "downloadUrl": "GitHub Release asset URL",
      "sha256": "",
      "sizeBytes": 0
    }
  ]
}
```

Katalog indirilemezse uygulama kurulu paketlerle çalışmaya devam etmelidir.

---

# 13. Paket güncelleme akışı

1. Katalog dosyasını indir
2. Kurulu sürümle karşılaştır
3. Güncelleme varsa kullanıcıya bildir
4. Geçici klasöre indir
5. SHA-256 doğrula
6. Arşivi güvenli biçimde aç
7. Manifest şemasını doğrula
8. Model uyumluluğunu doğrula
9. Atomik biçimde kur
10. Eski paketi yalnızca başarılı kurulumdan sonra sil

---

# 14. Paket güvenliği

Şunları uygula:

- SHA-256 doğrulama
- Zip Slip koruması
- Path traversal koruması
- Maksimum açılmış boyut
- Maksimum dosya sayısı
- Maksimum sıkıştırma oranı
- Manifest schema doğrulama
- Paket ID sanitization
- Model/paket uyumluluk kontrolü
- HTTPS
- Atomik kurulum
- Geçici dosya temizliği
- Yarım kalan indirmeden kurtarma
- Kurulu paketin bozulmaması
- Mümkünse HTTP Range ile devam eden indirme
- Gelecekte dijital imza doğrulama arayüzü

---

# 15. Fotoğraf tanımlama akışı

İlk sürümde kamera kullanma.

Ana eylem:

```text
Fotoğraf Seç
```

Akış:

```text
Galeri
→ fotoğraf seç
→ EXIF oku
→ önizleme
→ konum seçimi
→ tarih seçimi
→ aktif paket kontrolü
→ cihaz üzerinde inference
→ bölgesel/mevsimsel yeniden sıralama
→ top-5 sonuç
```

Desteklenecek durumlar:

- Büyük fotoğraf
- EXIF rotation
- JPEG
- PNG
- HEIC/HEIF
- Bozuk görüntü
- Çok küçük görüntü
- Kuş bulunamaması
- Birden fazla kuş
- Kuşun çok küçük olması
- Düşük güven
- Model veya paket bulunamaması

---

# 16. Inference mimarisi

Aşağıdaki katmanları oluştur:

```dart
abstract interface class BirdDetector {
  Future<List<BirdBoundingBox>> detect(ImageInput image);
}

abstract interface class BirdClassifier {
  Future<List<SpeciesPrediction>> classify(
    ImageInput image,
    CandidateSpeciesSet candidates,
  );
}

abstract interface class PredictionReranker {
  Future<List<SpeciesPrediction>> rerank(
    List<SpeciesPrediction> predictions,
    ObservationContext context,
  );
}
```

İlk aşamada deterministik mock implementasyonlar kullan.

Daha sonra:

- TFLite/LiteRT
- ONNX Runtime Mobile
- Android native adapter
- iOS Core ML adapter

eklenebilsin.

---

# 17. Model stratejisi

Model henüz hazır değildir.

Bu nedenle mobil geliştirmeyi durdurma.

## Aşama A — Mock inference

- Deterministik mock detector
- Deterministik mock classifier
- Örnek fotoğraflar için sabit sonuç
- Uçtan uca kullanıcı akışı

## Aşama B — Teknik test modeli

Lisansı uygun küçük bir TFLite modeliyle:

- Model yükleme
- Tensor dönüşümü
- Preprocessing
- Background inference
- Sonuç okuma
- Bellek yönetimi
- Android 9 uyumluluğu

test edilir.

## Aşama C — Gerçek FirBird modeli

Önerilen yaklaşım:

```text
Lisansı doğrulanmış kuş görüntüleri
+ topluluk tarafından doğrulanmış FirBird verileri
→ train/validation/test ayrımı
→ BioCLIP veya BioCLIP 2 öğretmen sinyali
→ MobileNetV3, MobileViT veya benzeri öğrenci model
→ knowledge distillation
→ quantization-aware training
→ INT8 TFLite
→ Android benchmark
```

Alternatif:

```text
MobileCLIP görüntü encoder
+ önceden hesaplanmış tür prototipleri
```

BioCLIP'i doğrudan mobilde varsayılan model yapma.

Model kullanmadan önce şunları doğrula:

- Kod lisansı
- Model ağırlığı lisansı
- Eğitim verisi lisansı
- Türetilmiş model koşulları
- Yeniden dağıtım hakkı

---

# 18. Bölgesel ve mevsimsel yeniden sıralama

Temel yaklaşım:

```text
log(finalScore) =
a × log(visualScore)
+ b × log(geographicPrior)
+ c × log(seasonalPrior)
+ d × log(habitatPrior)
```

Desteklenecek durumlar:

- Kesin konum
- Yaklaşık bölge
- Yalnızca ülke
- Konum bilinmiyor
- Tarih bilinmiyor
- EXIF tarihi
- Elle seçilen tarih
- Türün birden fazla pakette bulunması
- Görsel skor yüksek ama bölgesel skor düşük
- Nadir göçmen tür
- Prior verisi eksik

Coğrafi bilgi türü tamamen silmemeli.

Varsayılan olarak yalnızca yeniden sıralama yapmalı.

---

# 19. Sonuç ekranı

Gösterilecek bilgiler:

- Türkçe tür adı
- Bilimsel ad
- İngilizce ad
- Familya
- İlk eşleşme
- Top-5 aday
- Güven seviyesi
- Benzer türler
- Ayırt edici özellikler
- Türkiye'de görülme durumu
- Mevsim bilgisi
- Habitat
- Boyut
- Beslenme
- Göç durumu
- Koruma durumu
- Aktif bölge paketi
- Konumun sonucu etkileyip etkilemediği
- Tarihin sonucu etkileyip etkilemediği
- Model sürümü
- Paket sürümü

Gerçek kalibrasyon yapılmadan yüzde gösterme.

Şu seviyeleri kullan:

```text
Yüksek eşleşme
Orta eşleşme
Düşük eşleşme
```

Düşük güven durumunda:

```text
Bu fotoğraf için güvenilir bir tür sonucu bulunamadı.
Aşağıdaki türler olası eşleşmelerdir.
```

---

# 20. Tür detay ekranı

Alanlar:

- Yerel ad
- Bilimsel ad
- İngilizce ad
- Taksonomi
- Kısa açıklama
- Fiziksel özellikler
- Dişi/erkek/yavru farkları
- Benzer türlerden ayrım
- Habitat
- Beslenme
- Davranış
- Göç durumu
- Türkiye dağılımı
- Yıl içindeki görülme dönemleri
- Koruma durumu
- Kaynaklar
- Lisans ve attribution

Bilgi yoksa uydurma.

---

# 21. Paylaşım

Kullanıcı sonucu paylaşabilsin.

Paylaşım içeriği:

- Tür adı
- Bilimsel ad
- Güven seviyesi
- Tanımlama tarihi
- FirBird proje adı

Kesin koordinat varsayılan olarak paylaşılmamalıdır.

Fotoğraf ayrıca paylaşılacaksa kullanıcıdan ayrı onay alınmalıdır.

Örnek paylaşım:

```text
FirBird bu kuşu yüksek olasılıkla Saka
(Carduelis carduelis) olarak eşleştirdi.
```

Sonucu kesin gerçek gibi sunma.

---

# 22. Gizlilik

Varsayılan ilkeler:

- Fotoğraf cihazdan çıkmaz
- Konum cihazdan çıkmaz
- EXIF verisi sunucuya gönderilmez
- Tanımlama geçmişi yalnızca cihazda tutulur
- Geçmiş kapatılabilir
- Geçmiş tamamen silinebilir
- Kesin konum paylaşılmaz
- Analytics varsayılan olarak kapalıdır
- Açık onay olmadan telemetry gönderilmez
- Crash loglarında fotoğraf URI'si veya koordinat bulunmaz

`docs/privacy/PRIVACY.md` oluştur.

---

# 23. Tam açık kaynak lisans kararı

FirBird kodu tamamen açık kaynak olacaktır.

Kod lisansı:

```text
Apache License 2.0
SPDX-License-Identifier: Apache-2.0
```

İzin verilen kullanımlar:

- Kişisel kullanım
- Akademik kullanım
- Ticari kullanım
- Kaynak kodunu değiştirme
- Fork oluşturma
- Yeniden dağıtma
- Derlenmiş uygulamayı satma
- Kapalı kaynak ticari ürüne entegre etme
- Alt lisanslama, Apache-2.0 koşulları dahilinde

Repository kökünde resmi Apache License 2.0 metni bulunan `LICENSE` dosyası oluştur.

`NOTICE` dosyası oluştur:

```text
FirBird
Copyright 2026 FirBird contributors

Licensed under the Apache License, Version 2.0.
```

Kaynak dosyalarında uzun lisans başlığı zorunlu değildir.

Gerekli yerlerde kısa SPDX satırı kullanılabilir:

```text
SPDX-License-Identifier: Apache-2.0
```

README içinde açıkça belirt:

```text
FirBird is licensed under the Apache License 2.0.
Commercial use, modification, redistribution, and sale are permitted
subject to the terms of the license.
```

`LICENSE_SELECTION_REQUIRED.md` oluşturma.

---

# 24. Marka yaklaşımı

`TRADEMARKS.md` oluştur.

İlk içerik:

```text
The FirBird source code is licensed under the Apache License 2.0.

Forks and modified distributions are welcome. To avoid user confusion,
materially modified distributions should clearly state that they are
unofficial and should use a distinguishable application name and icon
unless explicit permission is granted.
```

Bu belge açık kaynak haklarını kısıtlamak için kullanılmamalıdır.

Amaç yalnızca resmi sürüm ile üçüncü taraf sürümlerin karıştırılmasını önlemektir.

---

# 25. Kod, veri ve model lisanslarını ayır

Apache-2.0 yalnızca FirBird kaynak koduna otomatik olarak uygulanır.

Aşağıdaki içeriklerin lisansı ayrıca izlenmelidir:

- Kuş fotoğrafları
- Tür açıklamaları
- Harita verileri
- Eğitim verileri
- Model ağırlıkları
- Ses kayıtları
- İkonlar
- Topluluk katkıları
- Taksonomi verileri

Oluştur:

```text
LICENSE
NOTICE
TRADEMARKS.md
THIRD_PARTY_NOTICES.md
docs/data/DATA_LICENSING.md
docs/model/MODEL_LICENSING.md
```

Lisansı doğrulanmayan içerikleri release paketine ekleme.

Model manifestinde:

```json
{
  "license": "SPDX veya lisans kimliği",
  "source": "model kaynağı",
  "trainingDataStatement": "eğitim verisi özeti",
  "redistributionAllowed": true
}
```

Paket manifestinde:

```json
{
  "licenses": [
    {
      "component": "species metadata",
      "license": "lisans kimliği",
      "attributionPath": "attribution/species-metadata.txt"
    }
  ]
}
```

---

# 26. Katkı kuralları

`CONTRIBUTING.md` içinde belirt:

```text
By submitting a contribution, you agree that your contribution may be
distributed under the Apache License 2.0.
```

İlk aşamada Contributor License Agreement zorunlu değildir.

İsteğe bağlı olarak DCO uygulanabilir.

Katkı sürecini MVP aşamasında gereksiz yere zorlaştırma.

---

# 27. Topluluk etiketleme sistemi

FirBird ileride kullanıcıların kuş fotoğraflarını etiketlemesiyle geliştirilecektir.

Bu sistem ilk mobil MVP'nin parçası değildir.

Ancak veri modeli ve dokümantasyonu hazırlanmalıdır.

Akış:

```text
Katılımcı fotoğraf yükler
→ lisans ve kullanım izni
→ EXIF temizleme
→ bounding box etiketi
→ tür etiketi
→ güven seviyesi
→ topluluk veya uzman doğrulaması
→ moderasyon
→ veri sürümüne dahil etme
→ model eğitimi
→ değerlendirme
→ yeni model release
```

Temel alanlar:

```text
annotationId
imageId
contributorId veya anonim token
speciesId
boundingBoxes
lifeStage
sex
confidence
country
approximateRegion
captureMonth
sourceLicense
consentVersion
annotationStatus
reviewers
createdAt
updatedAt
```

Durumlar:

```text
pending
community-reviewed
expert-reviewed
rejected
disputed
training-approved
```

Tek kişinin etiketi otomatik doğru kabul edilmemelidir.

---

# 28. Etiketleme gizliliği

Planla:

- EXIF konumunu varsayılan kaldırma
- Kesin koordinatı yayınlamama
- Nadir tür konumunu gizleme
- İnsan yüzü ve plaka kontrolü
- Açık lisans onayı
- Fotoğraf kaldırma talebi
- Veri sürümlerinden kaldırma politikası
- Katılımcının katkısını geri çekme süreci
- Eğitim verisi provenance kaydı

Büyük ham fotoğrafları normal Git repository'sine ekleme.

GitHub sadece metadata, issue ve PR süreçleri için kullanılabilir.

Gerçek obje depolama daha sonra seçilebilir.

---

# 29. Veri kalite stratejisi

Aynı fotoğraf serisini train ve validation arasında bölme.

Gruplama alanları:

```text
observationId
photographerId
captureSessionId
locationGrid
captureDate
```

Raporlanacak metrikler:

- Top-1 accuracy
- Top-5 accuracy
- Macro F1
- Tür başına recall
- Familya düzeyi doğruluk
- Bölgeye göre performans
- Mevsime göre performans
- Nadir tür performansı
- Bilinmeyen tür reddetme başarısı
- Kalibrasyon
- Model boyutu
- Inference süresi
- Peak RAM

---

# 30. Yerel veri modeli

En az şu domain modellerini oluştur:

```text
Species
Taxon
SpeciesName
SpeciesPrediction
ObservationContext
GeographicPrior
SeasonalPrior
HabitatPrior
RegionPackage
RegionPackageManifest
InstalledPackage
PackageDownload
ModelInfo
InferenceMetrics
IdentificationRecord
AnnotationRecord
LicenseRecord
```

Tür kimlikleri paketler arasında kararlı olmalıdır.

External ID alanları bulunabilsin:

- eBird
- GBIF
- iNaturalist
- IOC
- Clements
- BirdLife

---

# 31. Tanıma geçmişi

Drift + SQLite ile cihazda sakla.

Varsayılan:

- Küçük thumbnail saklanabilir
- Orijinal fotoğraf kopyalanmamalı
- URI referansı kullanılabilir
- URI erişimi kaybolursa uygulama çökmemeli
- Kullanıcı tek kaydı silebilmeli
- Kullanıcı tüm geçmişi silebilmeli
- Geçmiş tamamen kapatılabilmeli

---

# 32. Ekranlar

## Onboarding

- FirBird nedir
- Offline çalışma
- Fotoğrafların cihazdan çıkmaması
- Türkiye paketinin kurulması
- Açık kaynak proje bağlantısı

## Ana ekran

- Fotoğraf seç
- Son tanımlamalar
- Bölge paketleri
- Kuşları keşfet
- Ayarlar

## Fotoğraf önizleme

- Fotoğraf
- Değiştir
- Konum
- Tarih
- Aktif paket
- Tanımla

## Konum seçimi

- EXIF konumu
- Harita
- Mevcut konum
- Bölge listesi
- Bilinmiyor

## Analiz

- Görsel hazırlanıyor
- Kuş aranıyor
- Türler karşılaştırılıyor
- Bölgesel sonuçlar hesaplanıyor

## Sonuç

- İlk eşleşme
- Top-5
- Güven
- Açıklama
- Benzer türler
- Paylaş
- Sonucu düzelt
- Tür detayına git

## Tür detayları

- Açıklama
- Dağılım
- Mevsim
- Habitat
- Benzer türler
- Kaynaklar
- Attribution

## Paketler

- Keşfet
- Yüklü
- Güncellemeler
- İndirme ilerlemesi
- Silme
- Depolama kullanımı

## Ayarlar

- Dil
- Konum tercihi
- EXIF kullanımı
- Geçmiş
- Gizlilik
- Paketler
- Model bilgisi
- Lisanslar
- GitHub proje bağlantısı

---

# 33. Yerelleştirme ve erişilebilirlik

İlk diller:

- Türkçe
- İngilizce

Tüm metinleri localization kaynaklarında tut.

Destekle:

- TalkBack
- Dynamic text size
- Yeterli dokunma alanı
- Karanlık tema
- Renk dışında durum göstergeleri
- Görsel içerik açıklamaları
- İleride RTL desteği

---

# 34. Hata tipleri

Domain seviyesinde anlamlı hata tipleri oluştur:

```text
NoPackageInstalled
ModelNotAvailable
ImageDecodeFailed
NoBirdDetected
InferenceFailed
PackageDownloadFailed
ChecksumMismatch
InsufficientStorage
PackageIncompatible
LocationUnavailable
PermissionDenied
ExifReadFailed
CatalogUnavailable
OfflineResourceMissing
```

Kullanıcıya teknik exception gösterme.

Loglarda hassas veri tutma.

---

# 35. Offline gereksinimleri

Uçak modunda çalışması gereken özellikler:

- Uygulama açılışı
- Fotoğraf seçme
- EXIF okuma
- Bölge listesinden seçim
- Daha önce seçilen harita bölgesini kullanma
- Kurulu Türkiye paketini kullanma
- Tanımlama
- Tür detayları
- Offline küçük görseller
- Geçmiş
- Paylaşım metni
- Model ve paket sürüm bilgisi

İnternet yalnızca:

- Paket indirme
- Model indirme
- Güncelleme kontrolü
- GitHub sayfası
- Gelecekte veri katkısı

için gereklidir.

---

# 36. Performans hedefleri

İlk hedefler:

- Orta seviye Android cihazda tek fotoğraf analizi mümkünse 2 saniye altında
- UI thread bloklanmamalı
- Model warm-up ölçülmeli
- Peak RAM ölçülmeli
- Gereksiz bitmap kopyaları yapılmamalı
- Model uygulama oturumunda yeniden kullanılmalı
- Büyük arşivler stream edilerek açılmalı
- Büyük dosyalar RAM'e tamamen alınmamalı
- Android 9 cihaz profili ayrıca test edilmeli

Benchmark sonuçlarını belge:

```text
docs/model/BENCHMARKING.md
```

---

# 37. Test stratejisi

## Unit testler

- Manifest parsing
- SemVer karşılaştırma
- SHA-256
- Güvenli arşiv açma
- Paket uyumluluğu
- Atomik kurulum
- Katalog parsing
- Reranking
- Konum bilinmiyor
- Tarih bilinmiyor
- EXIF tarih seçimi
- EXIF konum onayı
- Güven seviyesi
- Top-5
- Mock inference
- Paylaşım metni
- Lisans manifest doğrulama

## Widget testleri

- Ana ekran
- Fotoğraf seçimi
- Konum seçenekleri
- Tarih seçenekleri
- Sonuç ekranı
- Düşük güven
- Paket indirme

## Integration test

1. Uygulamayı aç
2. Örnek Türkiye paketini kur
3. Örnek fotoğraf seç
4. Bölge belirle
5. Tarih seç
6. Mock tanımlamayı çalıştır
7. Sonucu doğrula
8. Tür detayını aç
9. Paylaşım metnini doğrula
10. Offline akışta tekrar çalıştır

## Güvenlik testleri

- `../` içeren arşiv
- Mutlak yol
- Yanlış checksum
- Eksik manifest
- Aşırı dosya sayısı
- Aşırı açılmış boyut
- Geçersiz package ID
- Uyumsuz model
- Yarım kalan kurulum
- Geçersiz lisans alanları

---

# 38. CI/CD

GitHub Actions oluştur.

Pull request kontrolleri:

```text
dart format kontrolü
flutter analyze
flutter test
package-builder testleri
manifest validation
security tests
Android debug build
```

Release workflow:

```text
Git tag
→ Flutter Android build
→ checksum üret
→ release notes üret
→ GitHub Release oluştur
→ APK/AAB yükle
→ paket/model asset yükle
→ katalog dosyasını üret
```

İmzalama anahtarını repository'ye ekleme.

---

# 39. Dokümantasyon

Oluştur:

```text
README.md
CONTRIBUTING.md
CODE_OF_CONDUCT.md
SECURITY.md
TRADEMARKS.md
THIRD_PARTY_NOTICES.md
NOTICE
LICENSE

docs/PROJECT_PLAN.md
docs/ROADMAP.md
docs/TESTING.md
docs/IOS_PLAN.md

docs/architecture/OVERVIEW.md
docs/architecture/INFERENCE.md
docs/architecture/FLUTTER_NATIVE_BOUNDARY.md
docs/architecture/LOCATION_CONTEXT.md

docs/package_format/SPECIFICATION.md

docs/model/MODEL_STRATEGY.md
docs/model/MODEL_LICENSING.md
docs/model/BENCHMARKING.md

docs/data/DATA_PIPELINE.md
docs/data/DATA_LICENSING.md

docs/labeling/ANNOTATION_SPEC.md
docs/labeling/MODERATION.md

docs/privacy/PRIVACY.md
```

---

# 40. Geliştirme fazları

## Faz 0 — Repository ve Flutter başlangıcı

- Yeni Git repository oluştur
- Flutter uygulaması oluştur
- Uygulama kimliği `org.firbird.app`
- Android minSdk 28
- Riverpod
- go_router
- Türkçe ve İngilizce
- Material 3 tema
- İlk build
- ADR belgeleri

Başarı:

```text
FirBird Android debug uygulaması build oluyor.
```

## Faz 1 — Navigasyon ve ekran iskeleti

- Onboarding
- Ana ekran
- Fotoğraf seçme
- Paketler
- Keşfet
- Ayarlar
- Tür detay placeholder

Başarı:

```text
Tüm temel ekranlar arasında gezinilebiliyor.
```

## Faz 2 — Fotoğraf seçme ve metadata

- image_picker
- Önizleme
- EXIF orientation
- EXIF tarih
- EXIF GPS tespiti
- Açık kullanıcı onayı
- Büyük görsel optimizasyonu
- Hata durumları

Başarı:

```text
Kullanıcı fotoğraf seçip metadata seçeneklerini görebiliyor.
```

## Faz 3 — Konum ve tarih bağlamı

- Harita
- Nokta seçimi
- Bölge listesi
- Mevcut konum
- Konum bilinmiyor
- Tarih seçimleri
- Gizlilik

Başarı:

```text
Kullanıcı fotoğrafın yaklaşık bölgesini ve tarihini belirleyebiliyor.
```

## Faz 4 — Mock inference

- Inference interface
- Mock detector
- Mock classifier
- Mock reranker
- Top-5
- Güven seviyeleri
- Sonuç ekranı
- Tür detayları
- Paylaşım

Başarı:

```text
Bir fotoğraf uçtan uca mock sonuç üretiyor.
```

## Faz 5 — Yerel veritabanı

- Drift
- Tür metadata
- Geçmiş
- Ayarlar
- Aktif paket
- Offline içerik

Başarı:

```text
Tanımlamalar yeniden başlatma sonrası görülebiliyor.
```

## Faz 6 — Türkiye paketi

- `.firbird` formatı
- Paket builder
- Örnek Türkiye paketi
- GitHub Release katalog adapter
- İndirme
- Checksum
- Güvenli kurulum
- Silme
- Güncelleme

Başarı:

```text
Türkiye paketi indiriliyor, kuruluyor ve offline okunuyor.
```

## Faz 7 — Bölgesel ve mevsimsel reranking

- Geographic prior
- Seasonal prior
- Konum bilinmiyor
- Tarih bilinmiyor
- Testler
- Açıklanabilir sonuç

Başarı:

```text
Aynı görsel adayları farklı bölge ve tarihe göre yeniden sıralanıyor.
```

## Faz 8 — Gerçek mobil inference

- TFLite adapter
- Test modeli
- Background çalışma
- Warm-up
- Lifecycle
- Quantized input/output
- Benchmark
- Android 9 testi

Başarı:

```text
Test TFLite modeli gerçek Android cihazda cihaz üzerinde çalışıyor.
```

## Faz 9 — Sağlamlaştırma

- Offline test
- Düşük depolama
- Bozuk paket
- Büyük fotoğraf
- Process death
- İndirme devamlılığı
- Android 9
- Erişilebilirlik
- Performans
- Bellek

## Faz 10 — İlk gerçek veri/model hattı

- Annotation schema
- Lisans kontrollü ingestion
- Dataset versioning
- Split stratejisi
- Training config
- Evaluation
- Model export
- GitHub Release

## Faz 11 — Balkanlar paketi

Türkiye paket sistemini değiştirmeden Balkanlar paketi ekle.

Ortak türler büyük model dosyalarını tekrar indirmemeli.

## Faz 12 — iOS

Android MVP kararlı olduktan sonra:

- iOS build
- Fotoğraf seçimi
- EXIF
- Harita ve konum
- Paket indirme
- SQLite uyumluluğu
- TFLite veya Core ML
- Background URLSession
- Paylaşım
- Aynı paket formatı
- Golden testler

---

# 41. Codex çalışma kuralları

Her görevin başında repository'yi incele.

Sonra:

1. Kısa uygulama planı çıkar
2. Dosyaları oluştur veya değiştir
3. Kod üretimini çalıştır
4. Format çalıştır
5. Analyze çalıştır
6. Testleri çalıştır
7. Android build al
8. Hataları düzelt
9. Dokümantasyonu güncelle
10. Bir sonraki mantıklı göreve geç

Yalnızca plan yazıp durma.

İç düşünce zincirini raporlama.

Bunun yerine şunları raporla:

- Alınan karar
- Gerekçe
- Değiştirilen dosyalar
- Çalıştırılan testler
- Sonuç
- Bilinen eksikler
- Sonraki adım

---

# 42. Her faz sonunda rapor formatı

```text
Tamamlananlar:
- ...

Değiştirilen önemli dosyalar:
- ...

Doğrulama:
- dart format
- flutter analyze
- flutter test
- Android build
- sonuçlar

Teknik kararlar:
- ...

Bilinen eksikler:
- ...

Sonraki uygulanan adım:
- ...
```

Görev bitmediyse rapordan sonra çalışmaya devam et.

---

# 43. İlk Codex görevi

Şimdi uygulamaya başla.

1. İçinde bulunduğun dizini incele
2. Repository yoksa yeni Git repository oluştur
3. `docs/PROJECT_PLAN.md` oluştur
4. `docs/decisions/0001-flutter-first.md` oluştur
5. `docs/decisions/0002-apache-2-license.md` oluştur
6. Flutter ile FirBird uygulamasını oluştur
7. Android minimum SDK'yı 28 yap
8. Uygulama kimliğini `org.firbird.app` yap
9. Riverpod, go_router, freezed, json_serializable ve lint araçlarını yapılandır
10. Türkçe ve İngilizce yerelleştirme ekle
11. Material 3 açık ve koyu tema oluştur
12. Onboarding ve ana ekran iskeletini oluştur
13. Ana ekrana şu eylemleri ekle:
    - Fotoğraf seç
    - Son tanımlamalar
    - Bölge paketleri
    - Kuşları keşfet
    - Ayarlar
14. Apache License 2.0 metniyle `LICENSE` oluştur
15. `NOTICE` oluştur
16. `TRADEMARKS.md` oluştur
17. `THIRD_PARTY_NOTICES.md` oluştur
18. `CONTRIBUTING.md` oluştur
19. `CODE_OF_CONDUCT.md` oluştur
20. `SECURITY.md` oluştur
21. `flutter pub get` çalıştır
22. Kod üretimi gerekiyorsa çalıştır
23. `dart format` çalıştır
24. `flutter analyze` çalıştır
25. `flutter test` çalıştır
26. Android debug build al
27. Tüm hataları düzelt
28. README'ye çalıştırma ve katkı talimatlarını ekle
29. Faz 1 tamamlanınca Faz 2'de fotoğraf seçme ve metadata akışına devam et
30. Yalnızca yapılacakları anlatma; repository üzerinde gerçekten uygula

---

# 44. Tamamlanma tanımı

Android MVP şu koşullarda tamamlanmış sayılır:

- Android 9+ yapılandırılmıştır
- Flutter uygulaması build edilir
- Fotoğraf seçme çalışır
- EXIF tarih ve konum bilgisi okunur
- Kullanıcı konumu elle veya otomatik seçebilir
- Konum bilinmiyor seçeneği vardır
- Mock inference uçtan uca çalışır
- Top-5 sonuç gösterilir
- Düşük güven durumu vardır
- Türkiye paketi kurulabilir
- Paket SHA-256 doğrulanır
- Paket güvenli biçimde açılır
- Paket silinir ve güncellenir
- Uçak modunda tanımlama çalışır
- Tür detay ekranı vardır
- Paylaşım vardır
- Geçmiş cihazda tutulur
- Testler geçer
- CI çalışır
- Apache-2.0 lisansı eklenmiştir
- Veri ve model lisansları ayrı izlenir
- iOS geçiş planı hazırlanmıştır
