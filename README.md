# FirBird

FirBird, kuş fotoğraflarını cihaz üzerinde tanımlamaya odaklanan açık kaynaklı bir Android uygulamasıdır. Fotoğraf ve konum bilgisi tanımlama amacıyla sunucuya gönderilmez.

> Proje aktif geliştirme aşamasındadır. Sonuçlar bir öneridir; özellikle nadir türlerde saha rehberleri ve güvenilir kaynaklarla doğrulanmalıdır.

## Bugünkü durum

- Galeriden fotoğraf seçme ve cihaz üzerinde tanımlama çalışır.
- BioCLIP-2 test modeliyle Türkiye için 464 aday tür kullanılır: 382 düzenli/göçmen tür ve 82 nadir kayıt.
- Sonuçta Türkçe, bilimsel ve İngilizce adlar; adaylar; görsel güven düzeyi; Trakuş ve Ornito.org bağlantıları gösterilir.
- Tanımlama geçmişi cihazda tutulur.
- Uygulama Android 9 (API 28) ve üzerini hedefler.
- Balkanlar paketi planlanmaktadır; Türkiye paketiyle birlikte kullanılabilecek ve tür kökenini gösterecektir.
- Planlanan `Yakınımdaki kuşlar` ekranı, seçilen konum ve mevsimde görülmesi beklenen türleri cihazda listeler.

İndirilebilir uygulama, model ve bölge paketi düzeni için [GitHub Releases planına](docs/package_format/GITHUB_RELEASES.md) bakın.

## Bölgesel kapsam ve Balkanlar

FirBird'ün mevcut cihaz testi Türkiye için **464 aday tür** kullanır: **382 düzenli/göçmen tür** ve **82 nadir kayıt**. Bu, Balkanlar paketi değildir.

Marmara'daki kuşlar Balkan göç yolları ve sınır habitatlarıyla yakından ilişkili olduğundan, Balkanlar FirBird için ayrı ama Türkiye ile birlikte çalışabilen bir bölge paketi olarak hazırlanır. Hedef kapsam Arnavutluk, Bosna-Hersek, Bulgaristan, Yunanistan, Hırvatistan, Karadağ, Kuzey Makedonya, Romanya, Sırbistan, Slovenya ve Kosova'dır.

Kalite karşılaştırması için güncel Balkan bölge kontrol listesi **542 tür** bildirmektedir. Bu sayı, yayımlanmış FirBird paketinin tür sayısı değildir; ortak türler tekilleştirildikten ve model taksonomisiyle eşleştirildikten sonra net paket sayısı yayımlanacaktır.

Her tanımlama sonucunda paket kapsamı görünür olacaktır:

- `Türkiye · yerleşik`
- `Türkiye · düzenli / göçmen`
- `Türkiye · nadir kayıt`
- `Balkanlar · düzenli`
- `Türkiye ve Balkanlar · ortak`

## Veri, lisans ve kalite yaklaşımı

FirBird, lisansı belirsiz veya ticari yeniden dağıtıma izin vermeyen tür/veri kayıtlarını yayımlanabilir paketlere eklemez. Balkan aday hattı yalnızca `CC0-1.0` ya da `CC-BY-4.0` kaynakları kabul eder; her kaynak için sürüm, erişim tarihi, lisans ve atıf kaydı pakette tutulur.

GBIF Backbone Taxonomy, bilimsel ad eşleştirmesi için CC BY 4.0 lisanslı başlangıç kaynağıdır. Avrupa Birliği ülkelerindeki resmî kuş dağılım verisi, Avrupa Çevre Ajansı'nın Article 12 veri setinden CC BY koşullarıyla değerlendirilmektedir. Telifli kontrol listeleri yalnızca yerel kalite kontrolü için referans alınır; FirBird paketine veya GitHub Releases varlığına kopyalanmaz.

Balkan adayları bilimsel ada göre tekilleştirilir, BioCLIP-2 metin vektörleriyle eşleştirilir ve Marmara fotoğraflarıyla gerçek cihazda test edilir. Ayrıntılar: [Balkan paket kapsamı](docs/data/BALKANS_PACKAGE_SCOPE.md) ve [veri kaynak politikası](docs/data/SOURCE_POLICY.md).

## Gizlilik

FirBird, tanımlama için fotoğrafı, EXIF bilgisini veya konumu bir sunucuya yüklemez. Geçmiş kayıtları yalnızca cihazda tutulur. İnternet bağlantısı yalnızca isteğe bağlı paket/model indirme ve dış bilgi kaynaklarını açma için gerekir.

## Geliştirme

Flutter SDK ve Android SDK kurulduktan sonra:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Bağlı Android cihazda çalıştırmak için:

```powershell
flutter run
```

Yerel olarak indirilen model ve ham veri dosyaları `tools/model_staging/` altında tutulur ve Git geçmişine eklenmez. Büyük paketler ileride GitHub Releases üzerinden dağıtılacaktır.

## Yol haritası

1. Türkiye paketi için indirilebilir, doğrulanabilir paket akışı
2. Balkanlar tür paketi ve Türkiye+Balkanlar birleşik aday listesi
3. Konum ve tarihe göre daha güçlü yeniden sıralama
4. Ses kaydından kuş tanıma
5. Android deneyimini sağlamlaştırma ve iOS hazırlığı

Detaylar için [ana geliştirme planına](FirBird_Codex_Master_Prompt.md) ve `docs/` altındaki kararlara bakın.

## Lisans

FirBird kaynak kodu [Apache License 2.0](LICENSE) ile lisanslanmıştır. Ticari kullanım, değiştirme, yeniden dağıtım ve satış; lisans koşullarına tabi olarak serbesttir.

Model ağırlıkları, kuş fotoğrafları ve tür verileri ayrı lisans koşullarına tabidir. Ayrıntılar için [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) dosyasına bakın.

## Katkı

Katkılar memnuniyetle karşılanır. Başlamadan önce [CONTRIBUTING.md](CONTRIBUTING.md) dosyasını okuyun.
