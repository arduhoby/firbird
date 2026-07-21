import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'bird_inference_engine.dart';

class OnnxBirdDetector implements BirdDetector {
  OnnxBirdDetector({required this.modelFile});

  final File modelFile;
  OrtSession? _session;
  final OnnxRuntime _runtime = OnnxRuntime();

  static const int _inputSize = 640;
  static const double _confidenceThreshold = 0.25;
  static const double _iouThreshold = 0.45;

  static Future<File> ensureModelExtracted() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File(path.join(directory.path, 'yolov8n.onnx'));
    
    if (!await file.exists()) {
      final ByteData data = await rootBundle.load('assets/models/yolov8n.onnx');
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await file.writeAsBytes(bytes);
    }
    
    return file;
  }

  Future<void> init() async {
    if (_session != null) return;
    
    if (!await modelFile.exists()) {
      throw Exception("YOLOv8 ONNX modeli bulunamadı: ${modelFile.path}");
    }
    
    _session = await _runtime.createSession(modelFile.path);
  }

  @override
  Future<List<BirdBoundingBox>> detect(ImageInput image) async {
    await init();
    
    final File file = File(image.uri);
    final Uint8List bytes = await file.readAsBytes();
    final img.Image? originalImage = img.decodeImage(bytes);
    
    if (originalImage == null) {
      return [];
    }

    final img.Image resizedImage = img.copyResize(originalImage, width: _inputSize, height: _inputSize);
    
    final Float32List inputBuffer = Float32List(1 * 3 * _inputSize * _inputSize);
    
    int pixelIndex = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final img.Pixel pixel = resizedImage.getPixel(x, y);
        inputBuffer[pixelIndex] = pixel.r / 255.0;
        inputBuffer[_inputSize * _inputSize + pixelIndex] = pixel.g / 255.0;
        inputBuffer[2 * _inputSize * _inputSize + pixelIndex] = pixel.b / 255.0;
        pixelIndex++;
      }
    }

    final OrtValue input = await OrtValue.fromList(
      inputBuffer,
      <int>[1, 3, _inputSize, _inputSize],
    );

    final OrtSession session = _session!;
    final Map<String, OrtValue> outputs = await session.run(<String, OrtValue>{
      session.inputNames.first: input,
    });

    final List<dynamic> values = await outputs.values.first.asFlattenedList();
    
    await input.dispose();
    for (final OrtValue output in outputs.values) {
      await output.dispose();
    }

    if (values.isEmpty) return [];

    final Float32List outputBuffer = Float32List.fromList(
      values.cast<num>().map((num value) => value.toDouble()).toList(),
    );
    
    const int numAnchors = 8400;
    
    final List<_BoxCandidate> candidates = [];

    for (int i = 0; i < numAnchors; i++) {
      // 'bird' sınıfı indeksi: 14. YOLO çıktısında skor indeksi: 4 + 14 = 18
      final double score = outputBuffer[18 * numAnchors + i];
      
      if (score >= _confidenceThreshold) {
        final double cx = outputBuffer[0 * numAnchors + i];
        final double cy = outputBuffer[1 * numAnchors + i];
        final double w = outputBuffer[2 * numAnchors + i];
        final double h = outputBuffer[3 * numAnchors + i];
        
        final double rx = (cx - w / 2) / _inputSize;
        final double ry = (cy - h / 2) / _inputSize;
        final double rw = w / _inputSize;
        final double rh = h / _inputSize;
        
        candidates.add(_BoxCandidate(
          box: BirdBoundingBox(
            left: rx.clamp(0.0, 1.0),
            top: ry.clamp(0.0, 1.0),
            width: rw.clamp(0.0, 1.0),
            height: rh.clamp(0.0, 1.0),
          ),
          confidence: score,
        ));
      }
    }
    
    return _applyNms(candidates).map((e) => e.box).toList();
  }

  List<_BoxCandidate> _applyNms(List<_BoxCandidate> boxes) {
    if (boxes.isEmpty) return [];
    
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    final List<_BoxCandidate> selected = [];
    final List<bool> active = List.filled(boxes.length, true);
    
    for (int i = 0; i < boxes.length; i++) {
      if (!active[i]) continue;
      
      final _BoxCandidate current = boxes[i];
      selected.add(current);
      
      for (int j = i + 1; j < boxes.length; j++) {
        if (!active[j]) continue;
        
        if (_calculateIou(current.box, boxes[j].box) > _iouThreshold) {
          active[j] = false;
        }
      }
    }
    
    return selected;
  }

  double _calculateIou(BirdBoundingBox box1, BirdBoundingBox box2) {
    final double x1 = math.max(box1.left, box2.left);
    final double y1 = math.max(box1.top, box2.top);
    final double x2 = math.min(box1.left + box1.width, box2.left + box2.width);
    final double y2 = math.min(box1.top + box1.height, box2.top + box2.height);

    final double w = math.max(0, x2 - x1);
    final double h = math.max(0, y2 - y1);
    final double interArea = w * h;

    final double box1Area = box1.width * box1.height;
    final double box2Area = box2.width * box2.height;

    return interArea / (box1Area + box2Area - interArea);
  }
}

class _BoxCandidate {
  _BoxCandidate({required this.box, required this.confidence});
  final BirdBoundingBox box;
  final double confidence;
}
