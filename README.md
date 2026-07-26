# FirBird 3

FirBird 3, kuş fotoğraflarını ve ortam seslerini cihaz üzerinde analiz eden,
offline-first bir Android kuş gözlem uygulamasıdır. Fotoğraf, ses kaydı ve GPS
konumu tanımlama amacıyla sunucuya gönderilmez.

> Güncel sürüm: **v0.5.0 (build 50)**. Tanımlar birer öneridir; özellikle nadir
> türler sahada güvenilir kaynaklarla doğrulanmalıdır.

## Öne çıkan özellikler

- **Görsel kuş tanımlama:** Kamera veya galeriden seçilen fotoğraflarda cihaz
  içindeki modelle tür adayları üretir.
- **Canlı ses dinleme:** BirdNET tabanlı analizle ortam sesini işler; tespitler
  canlı spektrogram üzerinde zaman damgası ile görünür.
- **Kayıt ve tek oynatıcı:** Canlı oturum WAV olarak kaydedilir. Kayıt bitince
  aynı ekran spektrogram, süre çubuğu, oynat/durdur düğmesi ve tespit çizgileri
  ile oynatıcıya dönüşür. Tespit kartından ilgili ana atlanabilir.
- **Tespit geri bildirimi:** Canlı tespitler doğru veya yanlış olarak
  işaretlenebilir; yanlış işaretlenen tür listeden kaldırılır.
- **Yanlış pozitif filtresi:** Sürekli ağustos böceği gibi kuş dışı seslerin
  kuş olarak gösterilmesini azaltmak için filtreleme uygulanır.
- **Bölgesel durum:** Yerleşik, düzenli/göçmen, nadir ve bölge dışı türler
  ayrı biçimde gösterilir.

## v0.5.0: offline eBird gözlem bağlamı

Uygulama, canlı dinlemede çıkan bir türün bulunduğunuz konumda yakın zamanda
raporlanıp raporlanmadığını çevrimdışı olarak gösterir.

- Türkiye'nin **81 ili** için hazırlanmış **4.857 eBird hotspot** ve **4.397
  son gözlem** özeti APK ile birlikte gelir.
- GPS konumu kullanılarak ayarlardan seçilen **20 km** veya **50 km** yarıçapta
  yakın hotspotlar ve ilgili türün son kayıtları değerlendirilir.
- Tespit kartına dokunulduğunda model skoru, bölgesel destek seviyesi, gözlem
  tarihi, konum adı ve veri kaynağı gösterilir.
- Bu bilgi modeli destekler; **yakın kaydın olmaması, türün bölgede olmadığı
  anlamına gelmez.**
- eBird API anahtarı uygulamada yer almaz ve canlı dinleme sırasında eBird'e
  ağ isteği yapılmaz.

Paket verisini yenilemek için geliştirici ortamında:

```powershell
.\tools\download_ebird_context_package.ps1
```

Bu araç veriyi il bazında indirir, kaynak zamanını ve SHA-256 bütünlük
hash'lerini `assets/ebird_context/manifest.json` dosyasına kaydeder.

## Gizlilik ve ağ kullanımı

- Tanımlama, ses analizi, kayıtlar ve bölgesel eBird bağlamı cihazda çalışır.
- eBird bağlam paketi indirildikten sonra kullanım için internet gerekmez.
- Harita zemini yalnızca kullanıcı o oturum için çevrimiçi haritayı açarsa
  OpenStreetMap'ten yüklenir.
- Kayıtlar ve kullanıcı tarafından verilen adlar cihazın yerel depolamasında
  saklanır.

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

## Lisans

FirBird kaynak kodu [Apache License 2.0](LICENSE) ile lisanslanmıştır.
