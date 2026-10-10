# FirBird iOS & Android — Claude AI Destekli Kuş Tanımlama ve Akıllı Ses Analizi

FirBird, Türkiye'deki kuş gözlemcileri ve saha araştırmacıları için geliştirilmiş; cihaz içi **BirdNET** derin öğrenme modelini ve **Anthropic Claude AI** büyük dil modelini (LLM) bir araya getiren yeni nesil **hibrit kuş tanımlama ve biyoakustik analiz** uygulamasıdır.

Mikrofondan gelen ortam sesi ve çekilen fotoğraflar cihaz üzerinde analiz edilir; kullanıcı dilediğinde canlı tespit sonuçlarını **Claude AI** ornitoloji uzmanlığı ile saniyeler içinde doğrulatabilir.

> 🌟 **Güncel Sürüm:** `v1.1.0 (build 110) / firbird4ios` — **Claude AI Hibrit Ornitoloji Sistemi, %400 Ses Kazancı, Akıllı Gürültü Filtresi ve Tam iOS Paritesi**

---

## 🤖 Neden Claude AI? (Hibrit Tanımlama Devrimi)

Geleneksel akustik modeller (BirdNET vb.) yalnızca ses spektrogram benzerlik skoruna bakar. Ancak sahada rüzgar, yankı, örtüşen kuş ötüşleri veya benzer frekanstaki mekanik sesler klasik modelleri yanıltabilir.

**FirBird Hibrit Mimarisi** bu sorunu Claude AI ile çözer:

1. **Çift Katmanlı Zeka:** Cihaz içi model mikrofon akışından ses pencerelerini anlık olarak işler ve aday türleri listeler.
2. **Ornitolojik Akıl Yürütme (Reasoning):** Kullanıcı Claude modunu seçtiğinde, aday tür bilgisi Anthropic Claude API'ye (`claude-3-5-haiku-20241022`) iletilir. Claude;
   - 📍 **Bölgesel Dağılım:** Türün Türkiye'deki ve bulunulan il/bölgedeki varlığını,
   - 📅 **Fenoloji & Mevsimsellik:** Göç dönemlerini, üreme takvimini ve kışlama olasılığını,
   - ⏰ **Biyolojik Ritim (Sirkadiyen Döngü):** Günün saatiyle türün ötüş alışkanlıklarının uyumunu,
   - 🔊 **Akustik Karışıklık Analizi:** Benzer ses çıkaran olası türleri ve sinyal kalitesini
   bütüncül bir biyolog gibi değerlendirir.
3. **Şeffaf Sonuç & Rozetleme:** Claude; tespit kartında `Doğrulandı`, `Olası`, `Düşük İhtimal` gibi net bir karar etiketi ve detaylı Türkçe uzman açıklaması sunar.
4. **Kesintisiz Ses Akışı:** Claude API çağrıları arka planda bağımsız asenkron görev olarak yürütülür; mikrofon akışı, PCM kaydı ve arayüz tepkiselliği hiçbir zaman kesintiye uğramaz.

---

## 🔑 Claude API Anahtarı ve Kullanım Modları

FirBird, kullanıcı gizliliğini ve esnekliğini ön planda tutar:

### 1. Lokal (On-Device) vs Claude AI Modu Seçimi
Uygulama içinde istediğiniz an iki mod arasında geçiş yapabilirsiniz:
- **`📱 Lokal (On-Device)`**: Tamamen çevrimdışı çalışır. İnternet bağlantısı gerekmez; cihaz içi BirdNET modeli kullanılır.
- **`🤖 Claude AI (Hibrit)`**: Yerel tespitleri Claude'un ornitoloji zekasıyla zenginleştirir ve canlı kartlarda doğrular.

> 💡 **Hızlı Geçiş:** Canlı Ses Tespiti ekranının sağ üst menüsündeki rozete dokunarak (`📱 Lokal` ↔ `🤖 Claude AI`) tek dokunuşla geçiş yapabilirsiniz.

### 2. API Anahtarı Nasıl Eklenir?
- **Ayarlar Menüsünden:** `Ayarlar → Yapay Zeka ve Değerlendirme Modu → Claude API Anahtarı` satırına dokunun.
- **Canlı Ekranda:** Canlı tespit ekranında `🤖 Claude AI` moduna dokunduğunuzda, anahtarınız henüz kayıtlı değilse doğrudan giriş penceresi açılır.
- **Canlı Bağlantı Doğrulama:** Anahtarınızı yapıştırdıktan sonra **"Bağlantıyı Test Et"** butonuna basarak Anthropic API sunucularıyla anlık bağlantı testini gerçekleştirebilirsiniz (HTTP 200 doğrulaması).

### 3. API Anahtarı Nasıl Değiştirilir veya Silinir?
- İstediğiniz zaman **Ayarlar → Claude API Anahtarı** penceresine girip yeni bir anahtar tanımlayabilir veya **"Anahtarı Kaldır"** butonuna basarak anahtarı cihazdan tamamen silebilirsiniz.

### 4. Güvenlik & Gizlilik İlkeleri
- API anahtarınız kesinlikle hiçbir üçüncü taraf sunucuya veya veri tabanına iletilmez.
- `FlutterSecureStorage` aracılığıyla doğrudan cihazın donanımsal güvenlik kasasında (**iOS Keychain / Android Keystore**) şifreli saklanır.
- Yalnızca Anthropic API uç noktasına doğrudan SSL/TLS üzerinden gönderilir.
- İnternet bağlantısı koptuğunda veya API kotası tükendiğinde uygulama kesintisiz olarak yerel **BirdNET** modunda çalışmaya devam eder.

---

## 🎛️ Ses Filtresi, %400 Kazanç ve Gürültü Azaltma (DSP)

Kuş sesleri genellikle 2 kHz – 8 kHz aralığındadır. Rüzgar, araba uğultuları, dere ve yaprak hışırtıları ise düşük frekanslarda yer alır.

- **%400 Ses Kazancı (Gain Boost):** Sahada uzakta kalan veya çok kısık öten kuş seslerini net duyabilmek için canlı dinleme ve kayıt oynatıcıda 4 kata kadar yazılımsal ses yükseltme.
- **Gürültü Azaltma (Noise Reduction) Toggle:** Rüzgar, uğultu ve çevre gürültüsünü anında kesmek için ses kontrolünün yanına pratik bir toggle butonu eklendi.
- **150 - 300 Hz High-Pass Filtre (Biquad HPF):** Rüzgar gürültüsünün %80'ini modele ve kulağa ulaşmadan kesen saf DSP filtresi.
- **Hazır Ortam Profilleri:** Ayarlar'dan 🌬️ Rüzgar, 💧 Dere/Akar Su ve 🌿 Orman hazır ses profilleri seçilebilir.

---

## 📱 iOS Paritesi & Donanım Optimizasyonu

- **iOS Mikrofon Düzeltmesi:** iPhone `AVAudioSession` ses yakalama hattı Android ile tam eş düzeye getirildi; kesintisiz PCM akışı sağlandı.
- **Dinamik Tespit Eşikleri:** Canlı dinleme devam ederken Ayarlar'dan değiştirilen aday gösterme (%45 vb.) ve tespit güven eşiklerinin anında devreye girmesi sağlandı.

---

## 🚀 Hızlı Başlangıç

1. Uygulamayı açın; mikrofon, kamera ve konum izinlerini verin.
2. [Anthropic Console](https://console.anthropic.com/)'dan temin ettiğiniz API anahtarını Ayarlar'dan girip doğrulayın.
3. Bir kuş fotoğrafını **Fotoğraftan Tanımla** ile seçin veya ortam sesini **Canlı Ses Tespiti** ile dinleyin.
4. Önerilen türün fotoğrafına, Türkçe/bilimsel adına, güven bilgisine ve Claude AI değerlendirmesine bakın.
5. Yakın çevredeki kayıtları görmek için **Yakınımdaki Kuşlar** ekranında **Mevcut konumumu kullan** seçeneğine dokunun.
6. Son eBird kayıtlarını yenilemek isterseniz kendi API anahtarınızı Ayarlar'da doğrulayın; ardından 20 veya 50 km verisini isteğe bağlı olarak indirin.

---

## 🔍 Öne Çıkan Özellikler

- **Claude AI Hibrit Canlı Değerlendirme:** Cihaz içi BirdNET tespitlerini Anthropic Claude AI (`claude-3-5-haiku`) ornitoloji modeliyle eşzamanlı değerlendirebilme.
- **Fotoğraftan Tanımlama:** Galeriden seçilen veya kamerayla çekilen kuş fotoğrafı cihaz üzerinde analiz edilir. EXIF tarih ve GPS bilgisi bağlam değerlendirmesinde kullanılır.
- **Canlı Ses Tespiti:** BirdNET tabanlı model mikrofon akışını sürekli analiz eder. Kayıt kesintisiz sürer ve tespitler zaman damgasıyla görünür.
- **Açıklanabilir Kanıt Sistemi:** Bir karta dokunulduğunda sonucu destekleyen, zayıflatan ve değerlendirilemeyen faktörleri listeleyen detaylı Kanıt Dosyası.
- **Kayıt ve Oynatıcı:** Canlı oturum WAV olarak saklanır. Oturum sonunda 30 saniyelik spektrogram, oynat/durdur, %400 ses seviyesi, gürültü filtresi ve tespit anına atlama seçenekleriyle tekrar dinlenebilir.
- **Kullanıcı Geri Bildirimi:** Canlı ses adayları **Doğru** veya **Doğru değil** olarak işaretlenebilir. Bu kararlar cihaz hafızasında tutularak sonraki tespitlerde doğruluk puanına katkı sağlar.
- **Nadir Tür Uyarısı:** Karar verilmemiş nadir tür kartı 15 saniyede bir turuncu parıltıyla uyarır.
- **Yakındaki Kuşlar & Hotspot Haritası:** GPS konumunun 20 km yarıçapında gözlenmiş türler ve eBird gözlem noktaları etkileşimli haritada listelenir.

---

## 🔒 Gizlilik ve Ağ Kullanımı

| İşlem | İnternet Gerekir mi? | Nerede Çalışır? |
| --- | --- | --- |
| Fotoğraftan tanımlama | Hayır | Cihazda |
| Canlı ses tespiti ve kayıt | Hayır | Cihazda |
| Geçmiş kayıtların oynatılması | Hayır | Cihazda |
| Bir yıllık eBird bağlamı | Hayır | Uygulama içindeki çevrimdışı paket |
| Harita zemini | Evet | OpenStreetMap katmanı |
| Kuş liste fotoğrafları | Evet | BirdNET/Cornell görsel kaynağı |
| Son 30 günlük eBird verisi | Evet, yalnızca kullanıcı isterse | Kişisel API anahtarıyla eBird |
| Claude AI canlı değerlendirme | Evet, yalnızca kullanıcı Claude modunu seçerse | Kişisel API anahtarıyla Anthropic Claude API |

Kişisel eBird ve Claude API anahtarları yalnızca cihazın güvenli donanım deposunda (`FlutterSecureStorage` - iOS Keychain / Android Keystore) saklanır. Canlı dinleme kendiliğinden veya kullanıcının açık onayı olmadan ağa istek atmaz. API anahtarları istenildiği an Ayarlar menüsünden değiştirilebilir veya silinebilir.

---

## 🛠️ İzinler

- **Kamera:** Yeni kuş fotoğrafı çekmek için.
- **Fotoğraf/medya:** Galeriden fotoğraf veya ses dosyası seçmek için.
- **Mikrofon:** Canlı ses tespiti ve kayıt için.
- **Konum:** Yakındaki türleri, hotspotları ve bölgesel bağlamı GPS'e göre hesaplamak için.
- **İnternet:** Harita zemini, kuş fotoğrafları, canlı eBird güncellemesi ve kullanıcı seçtiğinde Claude AI değerlendirmesi için.

---

## 💻 Geliştirme ve Derleme

```bash
# Bağımlılıkları yükleme
flutter pub get

# Statik analiz ve testler
flutter analyze
flutter test

# Android derleme
flutter build apk --release --target-platform android-arm64

# iOS derleme
flutter build ios --release --no-codesign
```

---

## 📜 Veri Kaynakları ve Lisans

- **Ornitolojik Zeka:** Anthropic Claude Messages API (`claude-3-5-haiku-20241022`).
- **Akustik Model:** BirdNET (Cornell Lab of Ornithology / Chemnitz University of Technology).
- **Gözlem Bağlamı:** [eBird](https://ebird.org/); eBird veri kullanım koşulları geçerlidir.
- **Kuş Fotoğrafları:** Cornell / BirdNET taksonomi görsel servisi.
- **Harita:** OpenStreetMap katkıcıları.
- **Kaynak Kod Lisansı:** [Apache License 2.0](LICENSE).
