import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firbird/inference/species_sex_age_policy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'bird_inference_engine.dart';
import 'sex_age_estimator.dart';

final candidateSpeciesProvider = FutureProvider<List<SpeciesPrediction>>((ref) async {
  final Directory directory = await OnnxBirdInferenceEngine.ensureTurkeyPackageInstalled();
  final File candidatesFile = File(path.join(directory.path, 'candidates.json'));
  if (!await candidatesFile.exists()) return const <SpeciesPrediction>[];
  final String content = (await candidatesFile.readAsString()).replaceAll('\uFEFF', '');
  final Map<String, dynamic> source = jsonDecode(content) as Map<String, dynamic>;
  final List<dynamic> json = source['candidates'] as List<dynamic>;
  return json
      .map((dynamic item) => _RegionalCandidate.fromJson(item as Map<String, dynamic>))
      .map((_RegionalCandidate c) => c.prediction(0.0))
      .toList();
});

/// BioCLIP-2 image encoder and regional candidate vectors.
/// Türkiye 0.1.0 ships with the app and is extracted once to app storage.
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
  SpeciesSexAgePolicyStore? _policyStore;
  final SexAgeEstimator _sexAgeEstimator = const PlaceholderSexAgeEstimator();

  static const String turkeyPackageVersion = '0.1.0';
  static const String _assetRoot = 'tools/model_staging/turkey_0.1.0';

  static Future<Directory> ensureTurkeyPackageInstalled() async {
    final Directory external = await getApplicationDocumentsDirectory();
    final Directory directory = Directory(
      path.join(external.path, 'firbird_test_model'),
    );
    final List<String> bundledFiles = <String>[
      'model.onnx',
      'embeddings.npy',
      'candidates.json',
    ];
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    for (final String name in bundledFiles) {
      final File target = File(path.join(directory.path, name));
      if (await target.exists() && name != 'candidates.json') continue;
      final ByteData bytes = await rootBundle.load('$_assetRoot/$name');
      await target.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }
    return directory;
  }

  Future<Directory> _directory() async {
    return ensureTurkeyPackageInstalled();
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
        'Türkiye 0.1.0 cihaz içi paketi hazırlanamadı.',
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
    _policyStore = await SpeciesSexAgePolicyStore.load();
  }

  @override
  List<SpeciesPrediction> get candidateSpecies {
    return _candidates?.map((_RegionalCandidate c) => c.prediction(0.0)).toList() ?? <SpeciesPrediction>[];
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
    final List<SpeciesPrediction> top5 = order
        .take(5)
        .map(
          (int index) =>
              _candidates![index].prediction(weights[index] / total),
        )
        .toList();

    // Cinsiyet & yaşam evresi tahmini — en yüksek skorlu tür üzerinden.
    SexAgePrediction? sexAge;
    if (top5.isNotEmpty && _policyStore != null) {
      final SpeciesSexAgePolicy policy =
          _policyStore!.forSpecies(top5.first.speciesId);
      sexAge = _sexAgeEstimator.estimate(
        speciesId: top5.first.speciesId,
        imageFeatures: features,
        policy: policy,
      );
    }

    return InferenceResult(
      predictions: top5,
      modelVersion: 'bioclip2-int8-turkey-0.1.0',
      locationAffectedResult: context.countryCode != null,
      dateAffectedResult: context.observationDate != null,
      sourceImageUri: image.uri,
      sexAge: sexAge,
    );
  }

  @override
  Future<ModelInformation> getModelInformation() =>
      Future<ModelInformation>.value(
        const ModelInformation(
          identifier: 'bioclip2-int8',
          version: turkeyPackageVersion,
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
