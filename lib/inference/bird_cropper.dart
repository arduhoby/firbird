import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'bird_inference_engine.dart';

class BirdCropper {
  /// Orijinal resmi [boundingBox] koordinatlarına göre kırpar ve
  /// kırpılmış resmi geçici bir dosyaya kaydederek yolunu döndürür.
  static Future<String?> cropBird(String imagePath, BirdBoundingBox boundingBox) async {
    final File originalFile = File(imagePath);
    if (!await originalFile.exists()) return null;

    final img.Image? originalImage = img.decodeImage(await originalFile.readAsBytes());
    if (originalImage == null) return null;

    // BoundingBox değerleri 0.0 - 1.0 arası oransal değerlerdir
    // Piksellere dönüştürüyoruz
    int x = (boundingBox.left * originalImage.width).round();
    int y = (boundingBox.top * originalImage.height).round();
    int width = (boundingBox.width * originalImage.width).round();
    int height = (boundingBox.height * originalImage.height).round();

    // Sınırları kontrol et
    x = x.clamp(0, originalImage.width);
    y = y.clamp(0, originalImage.height);
    
    // Genişlik ve yükseklik taşmalarını önle
    if (x + width > originalImage.width) {
      width = originalImage.width - x;
    }
    if (y + height > originalImage.height) {
      height = originalImage.height - y;
    }

    if (width <= 0 || height <= 0) return null;

    // Resmi kırp
    final img.Image croppedImage = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: width,
      height: height,
    );

    // Geçici dosyaya kaydet
    final Directory tempDir = await getTemporaryDirectory();
    final String tempPath = '${tempDir.path}/cropped_bird_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final File croppedFile = File(tempPath);
    await croppedFile.writeAsBytes(img.encodeJpg(croppedImage, quality: 90));
    
    return tempPath;
  }
}
