# Canlı ses için zamansal bağlam

FirBird, canlı ses tespitlerinde sabit saat eşiği kullanmaz. Konum izni varsa
cihazın UTC anı ile GPS koordinatından güneş yüksekliği hesaplanır ve sonuç
gündüz, sivil alacakaranlık, denizcilik alacakaranlığı, astronomik
alacakaranlık veya gece olarak sınıflanır. Konum yoksa ses modeli sonucu
değiştirilmez.

Bu bağlam bir **kesin eleme kuralı değildir**. Modelin ham skoru korunur;
yalnızca tekrar gerektiren orta güvenli adaylarda yumuşak bir ağırlık olarak
kullanılır. Çok yüksek ham güven, zaman bağlamı yüzünden gizlenmez.

## İlk davranış grupları

- Gececil: baykuş cinsleri ve çobanaldatan (*Caprimulgus*).
- Gece esnek: Bülbül (*Luscinia megarhynchos*), Kızılgerdan (*Erithacus
  rubecula*), Karakızılkuyruk (*Phoenicurus ochruros*) ve kamışçınlar
  (*Acrocephalus*). Bu türler gece otomatik elenmez.
- Belirgin gündüzcül: ağaçkakanlar ve seçilmiş yırtıcı kuş cinsleri. Gece
  ağırlıkları düşer ancak sıfıra inmez.
- Bilinmeyen: tarafsız kalır; katalogda davranış sınıfı olmayan tür için ek
  saat cezası uygulanmaz.

Gece göçü çağrıları tür ve kayıt tipine bağlı olduğundan ilk sürümde ayrıca
bir türü otomatik olarak "gece göçü" saymaz. Bu, saha kayıtlarıyla doğrulanacak
ayrı bir regresyon aşamasıdır.

## Kaynaklar

- Güneş yüksekliği, NOAA Solar Calculator denklemlerinin cihaz içi yaklaşık
  uygulamasıyla hesaplanır. NOAA sivil alacakaranlığı Güneş -6° iken tanımlar
  ve hesaplarının astronomik algoritmalara dayandığını belirtir. Erişim:
  2026-07-26. <https://gml.noaa.gov/grad/solcalc/glossary.html>
  <https://gml.noaa.gov/grad/solcalc/calcdetails.html>
- Kızılgerdan için Cornell tür sayfası yıl içindeki ötüş davranışını açıklar;
  gece göçündeki akustik kayıtların yalnızca çağrı yapan kuşları yakaladığını
  Cornell ayrıca belirtir. Erişim: 2026-07-26.
  <https://www.allaboutbirds.org/guide/European_Robin/sounds>
  <https://www.birds.cornell.edu/home/new-tech-to-id-night-migrating-birds/>

Davranış sınıfları sürümlü veri olarak tutulmalıdır; bu başlangıç listesi
Türkiye saha verisi ve uzman doğrulamasıyla genişletilecektir.
