# GitHub Releases dağıtım planı

FirBird kaynak kodu GitHub repository'sinde tutulur. Büyük model, aday vektörü ve bölge paketleri Git geçmişine eklenmez; GitHub Releases varlığı olarak dağıtılır.

## Yayın türleri

### Uygulama yayını

Her uygulama sürümü aşağıdaki dosyaları içerir:

- `firbird-vX.Y.Z-android.apk`: Android için doğrudan kurulabilir paket
- `firbird-vX.Y.Z-android.aab`: Play Store için uygulama paketi
- `firbird-catalog-v1.json`: Paket/model kataloğu
- `SHA256SUMS.txt`: tüm varlıkların SHA-256 doğrulama özeti
- `RELEASE_NOTES.md`: kullanıcıya yönelik değişiklik notları

### Veri ve model yayını

- `turkey-all-vX.Y.Z.firbird`
- `balkans-vX.Y.Z.firbird`
- `bioclip2-int8-vX.Y.Z.onnx`
- `bioclip2-candidates-turkey-vX.Y.Z.firbird`
- `bioclip2-candidates-balkans-vX.Y.Z.firbird`
- `firbird-catalog-v1.json`
- `SHA256SUMS.txt`
- kaynak gösterimleri ve üçüncü taraf lisansları

## Paket kuralları

1. Paket URL'si HTTPS olmalıdır.
2. İndirme tamamlanmadan kurulu paket değiştirilmez.
3. SHA-256 kontrolü geçmeyen hiçbir dosya etkinleştirilmez.
4. Model ve aday paketi, uyumlu model kimliği/sürümü bildirmelidir.
5. Türkiye ve Balkanlar ayrı kurulabilir; ortak türler yalnızca bir kez değerlendirilir.
6. Her tür kaydı, `originScope` alanında Türkiye, Balkanlar veya ortak kapsamını belirtir.
7. Lisansı doğrulanmamış model, görsel veya tür verisi yayımlanmaz.
