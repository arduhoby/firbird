import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../inference/bird_inference_engine.dart';
import '../inference/onnx_bird_detector.dart';
import '../inference/bird_cropper.dart';

class CropConfirmationScreen extends StatefulWidget {
  const CropConfirmationScreen({required this.request, super.key});
  
  final IdentificationRequest request;

  @override
  State<CropConfirmationScreen> createState() => _CropConfirmationScreenState();
}

class _CropConfirmationScreenState extends State<CropConfirmationScreen> {
  bool _isDetecting = true;
  BirdBoundingBox? _box;
  late final OnnxBirdDetector _detector;
  ImageProvider? _imageProvider;
  
  @override
  void initState() {
    super.initState();
    _imageProvider = FileImage(File(widget.request.image.uri));
    _runDetection();
  }
  
  Future<void> _runDetection() async {
    try {
      final File modelFile = await OnnxBirdDetector.ensureModelExtracted();
      _detector = OnnxBirdDetector(modelFile: modelFile);
      final List<BirdBoundingBox> boxes = await _detector.detect(widget.request.image);
      if (boxes.isNotEmpty && mounted) {
        setState(() {
          _box = boxes.first;
          _isDetecting = false;
        });
        return;
      }
    } catch (e) {
      debugPrint('Detection failed: $e');
    }
    
    // Kuş bulunamazsa veya hata olursa doğrudan analize geç
    if (mounted) {
      _goToAnalysis(widget.request.image.uri);
    }
  }

  void _goToAnalysis(String imageUri) {
    context.pushReplacement(
      '/analysis',
      extra: IdentificationRequest(
        image: ImageInput(uri: imageUri),
        context: widget.request.context,
      ),
    );
  }

  Future<void> _cropAndProceed() async {
    setState(() => _isDetecting = true);
    try {
      final String? croppedPath = await BirdCropper.cropBird(
        widget.request.image.uri,
        _box!,
      );
      if (croppedPath != null && mounted) {
        _goToAnalysis(croppedPath);
        return;
      }
    } catch (e) {
      debugPrint('Crop failed: $e');
    }
    
    // Kırpma başarısız olursa orijinaliyle devam et
    if (mounted) {
      _goToAnalysis(widget.request.image.uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDetecting) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kuş Aranıyor...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: const Text('Kuş Tespit Edildi')),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  Image(image: _imageProvider!, fit: BoxFit.contain),
                  if (_box != null)
                    CustomPaint(
                      painter: BoundingBoxPainter(box: _box!),
                      child: Container(),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => _goToAnalysis(widget.request.image.uri),
                  child: const Text('İptal (Orijinal)'),
                ),
                FilledButton(
                  onPressed: _cropAndProceed,
                  child: const Text('Kırp ve Analiz Et'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BoundingBoxPainter extends CustomPainter {
  BoundingBoxPainter({required this.box});
  
  final BirdBoundingBox box;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
      
    final Rect rect = Rect.fromLTWH(
      box.left * size.width,
      box.top * size.height,
      box.width * size.width,
      box.height * size.height,
    );
    
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(BoundingBoxPainter oldDelegate) {
    return oldDelegate.box != box;
  }
}
