import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'bird_inference_engine.dart';

/// Test engine for the downloaded BioCLIP-2 image encoder and regional
/// candidate vectors. The large model stays outside the APK.
class OnnxBirdInferenceEngine implements BirdInferenceEngine {
  OnnxBirdInferenceEngine({
    required this.modelFile,
    required this.candidatesFile,
    required this.embeddingsFile,
  });

  factory OnnxBirdInferenceEngine.fromExternalTestFiles() {
    return OnnxBirdInferenceEngine(
      modelFile: 'model.onnx',
      candidatesFile: 'candidates.json',
      embeddingsFile: 'embeddings.npy',
    );
  }

  final String modelFile;
  final String candidatesFile;
  final String embeddingsFile;
  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;
  List<_RegionalCandidate>? _candidates;
  Float32List? _candidateEmbeddings;
  int _dimensions = 768;

  Future<Directory> _directory() async {
    final Directory? external = await getExternalStorageDirectory();
    if (external == null) {
      throw const StrongModelNotAvailableException(
        'Test model directory is unavailable.',
      );
    }
    return Directory(path.join(external.path, 'firbird_test_model'));
  }

  @override
  Future<void> warmUp() async {
    if (_session != null) return;
    final Directory directory = await _directory();
    final File onnx = File(path.join(directory.path, modelFile));
    final File candidates = File(path.join(directory.path, candidatesFile));
    final File embeddings = File(path.join(directory.path, embeddingsFile));
    if (!await onnx.exists() ||
        !await candidates.exists() ||
        !await embeddings.exists()) {
      throw const StrongModelNotAvailableException(
        'Guclu test modeli henuz telefona yuklenmedi.',
      );
    }
    _session = await _runtime.createSession(onnx.path);
    final Map<String, dynamic> source =
        jsonDecode(await candidates.readAsString()) as Map<String, dynamic>;
    _candidates = (source['candidates'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_RegionalCandidate.fromJson)
        .toList(growable: false);
    final Uint8List bytes = await embeddings.readAsBytes();
    final int headerLength = bytes[8] | (bytes[9] << 8);
    final String header = ascii.decode(bytes.sublist(10, 10 + headerLength));
    final RegExpMatch? shape = RegExp(
      r'\(\s*(\d+)\s*,\s*(\d+)\s*\)',
    ).firstMatch(header);
    if (shape == null || int.parse(shape.group(2)!) != _candidates!.length) {
      throw const StrongModelNotAvailableException('Aday vektor paketi bozuk.');
    }
    _dimensions = int.parse(shape.group(1)!);
    _candidateEmbeddings = Float32List.view(
      bytes.buffer,
      bytes.offsetInBytes + 10 + headerLength,
    );
  }

  @override
  Future<InferenceResult> identify(
    ImageInput image,
    IdentificationContext context,
  ) async {
    await warmUp();
    final OrtSession session = _session!;
    final List<dynamic> inputInfo = await session.getInputInfo();
    final List<dynamic> shape = inputInfo.first['shape'] as List<dynamic>;
    final int size = (shape.last as num).toInt();
    final Uint8List imageBytes = await File(image.uri).readAsBytes();
    final ui.Codec codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: size,
      targetHeight: size,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    final ByteData rgba = (await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    final Float32List pixels = Float32List(3 * size * size);
    const List<double> mean = <double>[0.48145466, 0.4578275, 0.40821073];
    const List<double> std = <double>[0.26862954, 0.26130258, 0.27577711];
    for (int y = 0; y < size; y++) {
      for (int x = 0; x < size; x++) {
        final int rgbaOffset = (y * size + x) * 4;
        for (int channel = 0; channel < 3; channel++) {
          pixels[channel * size * size + y * size + x] =
              (rgba.getUint8(rgbaOffset + channel) / 255 - mean[channel]) /
              std[channel];
        }
      }
    }
    frame.image.dispose();
    final OrtValue input = await OrtValue.fromList(pixels, <int>[
      1,
      3,
      size,
      size,
    ]);
    final Map<String, OrtValue> outputs = await session.run(<String, OrtValue>{
      session.inputNames.first: input,
    });
    final List<dynamic> values = await outputs.values.first.asFlattenedList();
    await input.dispose();
    for (final OrtValue output in outputs.values) {
      await output.dispose();
    }
    final Float32List features = Float32List.fromList(
      values.cast<num>().map((num value) => value.toDouble()).toList(),
    );
    double norm = 0;
    for (final double value in features) {
      norm += value * value;
    }
    norm = math.sqrt(norm);
    final List<double> logits = List<double>.generate(_candidates!.length, (
      int candidateIndex,
    ) {
      double dot = 0;
      for (int dimension = 0; dimension < _dimensions; dimension++) {
        dot +=
            (features[dimension] / norm) *
            _candidateEmbeddings![dimension * _candidates!.length +
                candidateIndex];
      }
      return dot * 100;
    });
    final double maxLogit = logits.reduce(
      (double a, double b) => a > b ? a : b,
    );
    final List<double> weights = logits
        .map((double value) => math.exp(value - maxLogit))
        .toList();
    final double total = weights.reduce((double a, double b) => a + b);
    final List<int> order = List<int>.generate(
      logits.length,
      (int index) => index,
    )..sort((int a, int b) => logits[b].compareTo(logits[a]));
    return InferenceResult(
      predictions: order
          .take(5)
          .map(
            (int index) =>
                _candidates![index].prediction(weights[index] / total),
          )
          .toList(),
      modelVersion: 'bioclip2-int8-turkey-balkans-test',
      locationAffectedResult: context.countryCode != null,
      dateAffectedResult: context.observationDate != null,
      sourceImageUri: image.uri,
    );
  }

  @override
  Future<ModelInformation> getModelInformation() =>
      Future<ModelInformation>.value(
        const ModelInformation(
          identifier: 'bioclip2-int8',
          version: 'test',
          isMock: false,
        ),
      );
  @override
  Future<void> dispose() async {
    if (_session != null) await _session!.close();
    _session = null;
  }
}

class _RegionalCandidate {
  const _RegionalCandidate({
    required this.scientificName,
    required this.occurrence,
    required this.turkishName,
    required this.englishName,
    required this.thumbnailUrl,
    required this.ornitoId,
  });
  factory _RegionalCandidate.fromJson(Map<String, dynamic> json) =>
      _RegionalCandidate(
        scientificName: json['scientificName']! as String,
        occurrence: json['occurrence']! as String,
        turkishName: json['turkishName'] as String? ?? '',
        englishName: json['englishName'] as String? ?? '',
        thumbnailUrl: json['imageUrl'] as String?,
        ornitoId: json['ornitoId'] as String?,
      );
  final String scientificName;
  final String occurrence;
  final String turkishName;
  final String englishName;
  final String? thumbnailUrl;
  final String? ornitoId;
  SpeciesPrediction prediction(double score) => SpeciesPrediction(
    speciesId: scientificName.toLowerCase().replaceAll(' ', '-'),
    turkishName: turkishName.trim().isEmpty ? scientificName : turkishName,
    scientificName: scientificName,
    englishName: englishName.trim().isEmpty ? scientificName : englishName,
    score: score,
    thumbnailUrl: thumbnailUrl,
    ornitoId: ornitoId,
    originLabel: switch (occurrence) {
      'accidental' => 'Türkiye · nadir kayıt',
      'regular-or-migratory' => 'Türkiye · düzenli / göçmen',
      'resident' => 'Türkiye · yerleşik',
      'balkans' => 'Balkanlar kapsamı',
      _ => occurrence,
    },
    alternativeNames: <String>[
      if (occurrence == 'accidental') 'Nadir / tesadufi kayit',
    ],
  );
}

class StrongModelNotAvailableException implements Exception {
  const StrongModelNotAvailableException(this.message);

  final String message;
}
