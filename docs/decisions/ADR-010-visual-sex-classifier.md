# ADR-010: Görsel cinsiyet sınıflandırıcısı

## Karar

FirBird 3, cinsiyet için tür adından türetilen veya rastlantısal skorlar
kullanmayacaktır. Gerçek bir sonuç yalnızca iNaturalist kaynaklı, lisansı
uygun, insan gözden geçirmesinden geçmiş fotoğraflarla eğitilen tür koşullu
modelden üretilecektir.

## Kapsam

- İlk sürüm yalnızca `tools/sex_model/species_v1.json` içindeki görsel
  dimorfizmi güçlü türleri hedefler.
- Tahmin modeli BioCLIP-2 görsel embedding'i üzerinde küçük bir erkek/dişi
  başlığıdır.
- Tür model kapsamında değilse ya da tür eşiğini geçemiyorsa sonuç `Belirsiz`
  olur.

## Kabul eşiği

Her tür, gözlemci bazında ayrılmış bağımsız test kümesinde en az %90 dengeli
doğruluk, her iki sınıfta en az %85 recall ve kalibre edilmiş güven eşiği
sağlamalıdır. Başarısız tür uygulamada kapalı kalır.

## Lisans ve gizlilik

Fotoğraf lisansı her örnekle birlikte saklanır. CC BY-NC ve tüm hakları saklı
fotoğraflar eğitim ya da ürün paketinde kullanılmaz. Hassas konumlar eğitim
manifestine alınmaz.
