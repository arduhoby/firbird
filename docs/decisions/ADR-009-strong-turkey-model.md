# ADR-009: Güçlü Türkiye kuş modeli

## Karar

İlk güçlü model denemesi için BioCLIP-2 INT8 ONNX görüntü kodlayıcısı kullanılacaktır.
Model, uygulamaya gömülmeyecek; doğrulanmış SHA-256 ile indirilebilir bir paket olacaktır.

## Gerekçe

- Genel ImageNet ve 964 türlük model, Türkiye türlerinde yeterli kapsama sahip değildir.
- BioCLIP-2, biyolojik türler için eğitilmiştir ve model paketi MIT lisanslıdır.
- INT8 ONNX sürümü yaklaşık 307 MB'tır; 599 MB'lık tam BioCLIP modelinden daha uygundur.
- Uygulama yalnızca Türkiye adaylarının önceden hesaplanmış metin gömmelerini indirerek dünya türleriyle yanlış eşleşmeleri azaltacaktır.

## Sonuçlar

- Android'de ONNX Runtime gerekir.
- Türkiye aday gömmeleri tamamlanana kadar bu paket son kullanıcı tanımlamasına açılmaz.
- Model paketi SHA-256 doğrulamasından sonra atomik olarak etkinleştirilir.
