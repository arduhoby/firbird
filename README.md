# FirBird (v0.3.2)

FirBird, kuş fotoğraflarını ve ses kayıtlarını **tamamen cihaz üzerinde (%100 çevrimdışı)** tanımlamaya odaklanan açık kaynaklı bir Android uygulamasıdır. Fotoğraf, ses ve konum bilgileri hiçbir sunucuya gönderilmez.

> Proje aktif geliştirme aşamasındadır (Güncel Sürüm: **v0.3.2**). Sonuçlar bir öneridir; özellikle nadir türlerde saha rehberleri ve güvenilir kaynaklarla doğrulanmalıdır.

---

## 🚀 Öne Çıkan Özellikler ve Yetenekler

- 📸 **Görsel Kuş Tanımlama**: Galeriden veya kameradan yüklenen fotoğraflarla BioCLIP-2 yapay zeka modeli kullanılarak yüksek doğrulukla tür tahmini.
- 🎙️ **Canlı Ses Tespit Modu**: Dahili BirdNET ONNX modeli (62 MB) ile her 3 saniyede bir ortam seslerini analiz etme, canlı tespit tablosu ve gerçek zamanlı equalizer.
- 🎨 **Tür Durumuna Göre Renkli Çerçeveler**:
  - 🟢 **Yeşil Çerçeve**: Yerel ve Göçmen Kuşlar (Türkiye yerleşik ve düzenli göçmen türleri)
  - 🔴 **Kırmızı Çerçeve**: Nadir Kuşlar (Türkiye'de nadir kaydı bulunan türler)
  - ⚪ **Gri Çerçeve**: Bölge Dışı / Olması Zor Kuşlar (Dünya türleri veya liste dışı kayıtlar)
- 📝 **Tablo Açıklama Notları**: Tespit tablolarının altında renk kodlarının anlamını gösteren dinamik bilgi notu.
- 📍 **Konum Bağlamı ve İzni**: Canlı ses dinleme ve yakınımda kuş arama ekranlarında hassas/yaklaşık konum uyumluluğu.
- 📜 **Akıllı Tanımlama Geçmişi**: Canlı ses oturumlarını tek bir özet kart olarak gruplama, modal detay tablosu ve WAV ses kaydına erişim.
- ☰ **Merkezi Navigasyon (AppDrawer)**: Ana Sayfa, Canlı Ses Tespiti, Son Tanımlamalar, Bölge Paketleri, Yakınımdaki Kuşlar ve Ayarlar sayfalarına her ekrandan erişim.
- 💯 **%100 Çevrimdışı Paket**: 503 kuş türü, Türkçe ve bilimsel isimler, görsel ve işitsel yapay zeka modelleri APK paketine dahildir. Kurulduktan sonra internet indirmesi gerekmez.

---

## 📊 Kapsam ve Kuş Sayıları

- **Toplam Desteklenen Kuş Türü**: **503 Tür** (Türkiye kuş faunası)
  - **Düzenli ve Göçmen Türler**: **421 Tür**
  - **Nadir Kayıtlar (Accidental)**: **82 Tür**
- **Ses Tanıma Destekli Türler**: BirdNET ONNX kütüphanesi kapsamında 6000+ dünya kuş sesi arasından Türkiye ve dünya kuşlarını anlık ayırt edebilme.

Her tanımlama sonucunda türün bölgesel kökeni açıkça gösterilir:
- `Türkiye · yerleşik`
- `Türkiye · düzenli / göçmen`
- `Türkiye · nadir kayıt`
- `Dünya Türü`

---

## 🛡️ Gizlilik

FirBird, tanımlama için fotoğrafları, ses kayıtlarını, EXIF verilerini veya konumu hiçbir sunucuya yüklemez. Geçmiş kayıtlar ve ses dosyaları yalnızca cihazınızın yerel hafızasında saklanır.

---

## 🛠️ Geliştirme ve Derleme

Flutter SDK ve Android SDK kurulduktan sonra:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --target-platform android-arm64 --release
```

Bağlı Android cihazda çalıştırmak ve kurmak için:

```powershell
flutter run
```

---

## 📜 Lisans

FirBird kaynak kodu [Apache License 2.0](LICENSE) ile lisanslanmıştır. Ticari kullanım, değiştirme, yeniden dağıtım ve satış lisans koşullarına tabi olarak serbesttir.
