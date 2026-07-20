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
