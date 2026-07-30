import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'package:firbird/audio/pcm16_wav.dart';
import 'package:firbird/species/species_catalog.dart';

import 'birdnet_label_filter.dart';
import 'bird_inference_engine.dart';
import 'model_coverage.dart';
import 'sex_age_estimator.dart';
import 'species_sex_age_policy.dart';

class AudioInput {
  const AudioInput({required this.uri});
  final String uri;
}

class AudioInferenceEngine implements BirdInferenceEngine {
  AudioInferenceEngine({required this.modelPath, required this.labelsPath});

  final String modelPath;
  final String labelsPath;
  List<String> _labels = [];
  Map<String, SpeciesPrediction>? _candidatesByScientificName;
  final List<SpeciesPrediction> _turkeyCandidates = <SpeciesPrediction>[];
  SpeciesSexAgePolicyStore? _policyStore;
  final SexAgeEstimator _sexAgeEstimator = const PlaceholderSexAgeEstimator();

  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;
  Future<void>? _warmUpFuture;

  static const int sampleRate = 48000;
  static const int chunkDurationSeconds = 3;
  static const int chunkSize =
      sampleRate * chunkDurationSeconds; // 144,000 samples

  @override
  List<SpeciesPrediction> get candidateSpecies =>
      List<SpeciesPrediction>.unmodifiable(_turkeyCandidates);

  @override
  Future<void> warmUp() => _warmUpFuture ??= _warmUp();

  Future<void> _warmUp() async {
    final File modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      try {
        final Directory parent = modelFile.parent;
        if (!await parent.exists()) await parent.create(recursive: true);
        final ByteData bytes = await rootBundle.load(
          'assets/models/birdnet.onnx',
        );
        await modelFile.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      } catch (e) {
        debugPrint('Could not extract birdnet.onnx from assets: $e');
      }
    }

    final File labelsFile = File(labelsPath);
    if (!await labelsFile.exists()) {
      try {
        final Directory parent = labelsFile.parent;
        if (!await parent.exists()) await parent.create(recursive: true);
        final ByteData bytes = await rootBundle.load(
          'assets/models/birdnet_labels.txt',
        );
        await labelsFile.writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          flush: true,
        );
      } catch (e) {
        debugPrint('Could not extract birdnet_labels.txt from assets: $e');
      }
    }

    // Create session
    _session = await _runtime.createSession(modelPath);

    // Load labels
    if (await labelsFile.exists()) {
      _labels = await labelsFile.readAsLines();
    } else {
      debugPrint('Labels file not found at $labelsPath');
    }

    // Bird metadata is resolved by the application-wide species catalog.
    try {
      final SpeciesCatalog catalog =
          await SpeciesCatalogRepository.instance.catalog;
      _candidatesByScientificName = {};
      _turkeyCandidates.clear();
      for (final SpeciesCatalogEntry entry in catalog.entries) {
        final String originLabel = switch (entry.occurrence) {
          'accidental' => 'Türkiye · nadir kayıt',
          'regular-or-migratory' => 'Türkiye · düzenli / göçmen',
          'resident' => 'Türkiye · yerleşik',
          'balkans' => 'Balkanlar kapsamı',
          _ =>
            entry.occurrence.isNotEmpty
                ? entry.occurrence
                : 'Türkiye · kayıtlı',
        };

        final SpeciesPrediction candidate = SpeciesPrediction(
          speciesId: entry.speciesId,
          turkishName: entry.turkishName,
          scientificName: entry.scientificName,
          englishName: entry.englishName,
          score: 0.0,
          thumbnailUrl: entry.imageUrl,
          ornitoId: entry.ornitoId,
          originLabel: originLabel,
        );
        _candidatesByScientificName![_candidateKey(entry.scientificName)] =
            candidate;
        _turkeyCandidates.add(candidate);
      }
      debugPrint(
        'BirdNET audio catalog loaded: '
        '${_candidatesByScientificName!.length} Türkiye species.',
      );
    } catch (e) {
      _candidatesByScientificName = <String, SpeciesPrediction>{};
      _turkeyCandidates.clear();
      debugPrint('Could not load BirdNET audio catalog: $e');
    }

    try {
      _policyStore = await SpeciesSexAgePolicyStore.load();
    } catch (e) {
      debugPrint('Could not load policy store for AudioInferenceEngine: $e');
    }
  }

  SpeciesPrediction? _candidateForScientificName(String scientificName) {
    final String lookupKey = _candidateKey(scientificName);
    final SpeciesPrediction? direct = _candidatesByScientificName?[lookupKey];
    if (direct != null) return direct;

    for (final SpeciesPrediction candidate in _turkeyCandidates) {
      if (_candidateKey(candidate.scientificName) == lookupKey) {
        return candidate;
      }
    }
    return null;
  }

  String _candidateKey(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Future<InferenceResult> identify(
    ImageInput audio,
    IdentificationContext context,
  ) async {
    await warmUp();

    if (_session == null) {
      throw StateError('AudioInferenceEngine is not initialized properly.');
    }

    final File sourceFile = File(audio.uri);
    if (!sourceFile.existsSync()) {
      throw ArgumentError('Audio file not found: ${audio.uri}');
    }

    // 1. Convert to WAV (48kHz, mono, 16-bit)
    final String tempWavPath =
        '${sourceFile.parent.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      await AudioDecoder.convertToWav(
        audio.uri,
        tempWavPath,
        sampleRate: sampleRate,
        channels: 1,
        bitDepth: 16,
      );

      // 2. Read the decoded WAV file
      final File wavFile = File(tempWavPath);
      final Uint8List wavBytes = await wavFile.readAsBytes();

      // 3. Extract PCM float data
      final Float32List pcmData = _parseWavToFloat32(wavBytes);
      return _identifyPcmData(pcmData, sourceUri: audio.uri);
    } finally {
      final File tempFile = File(tempWavPath);
      if (tempFile.existsSync()) tempFile.deleteSync();
    }
  }

  /// Runs BirdNET directly on live 48 kHz mono PCM16 audio. The microphone
  /// can remain open while overlapping model windows are analyzed.
  Future<InferenceResult> identifyPcm16(
    Uint8List pcmBytes,
    IdentificationContext context, {
    String sourceUri = 'live://microphone',
  }) async {
    await warmUp();
    if (_session == null) {
      throw StateError('AudioInferenceEngine is not initialized properly.');
    }
    return _identifyPcmData(_pcm16ToFloat32(pcmBytes), sourceUri: sourceUri);
  }

  Future<InferenceResult> _identifyPcmData(
    Float32List pcmData, {
    required String sourceUri,
  }) async {
    // Split into three-second chunks and run inference.
    final Map<int, double> maxProbabilities =
        {}; // speciesIndex -> max probability across chunks

    int offset = 0;
    while (offset + chunkSize <= pcmData.length) {
      final Float32List chunk = Float32List.sublistView(
        pcmData,
        offset,
        offset + chunkSize,
      );

      // Input tensor shape [1, 144000]
      final shape = [1, chunkSize];
      final OrtValue inputTensor = await OrtValue.fromList(chunk, shape);

      final List<dynamic> inputInfo = await _session!.getInputInfo();
      final String inputName = inputInfo.first['name'] as String;

      final Map<String, OrtValue> outputs = await _session!.run(
        <String, OrtValue>{inputName: inputTensor},
      );

      if (outputs.isNotEmpty) {
        final OrtValue outputTensor = outputs.values.first;
        final List<dynamic> outputData = await outputTensor.asFlattenedList();
        final List<double> logits = outputData
            .cast<num>()
            .map((num val) => val.toDouble())
            .toList();

        for (int i = 0; i < logits.length; i++) {
          final double prob = _sigmoid(logits[i]);
          if (prob > (maxProbabilities[i] ?? 0.0)) {
            maxProbabilities[i] = prob;
          }
        }
      }

      // Release resources
      await inputTensor.dispose();
      for (final OrtValue output in outputs.values) {
        await output.dispose();
      }

      offset += chunkSize;
    }

    // 5. Sort probabilities and map to SpeciesPrediction
    final List<MapEntry<int, double>> sortedProbs =
        maxProbabilities.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final List<String> rawTopLabels = sortedProbs
        .take(20)
        .map((MapEntry<int, double> entry) {
          final String label = entry.key < _labels.length
              ? _labels[entry.key]
              : 'Unknown-${entry.key}';
          return '$label=${entry.value.toStringAsFixed(3)}';
        })
        .toList(growable: false);
    debugPrint('BirdNET raw top: ${rawTopLabels.join(', ')}');

    final List<SpeciesPrediction> predictions = [];
    for (final entry in sortedProbs.take(20)) {
      final int index = entry.key;
      final double score = entry.value;

      if (score < 0.03) continue; // Noise threshold

      final String label = index < _labels.length
          ? _labels[index]
          : 'Unknown-$index';

      // BirdNET labels format: "Scientific_Name_Common_Name".
      final int underscoreIdx = label.indexOf('_');
      final String rawSciName = birdNetScientificName(label);
      String rawEngName = label;
      if (underscoreIdx != -1) {
        rawEngName = label
            .substring(underscoreIdx + 1)
            .trim()
            .replaceAll('_', ' ');
      } else {
        rawEngName = rawSciName;
      }

      // Only exact BirdNET background classes are rejected. Substring
      // matching would reject real taxa such as Carduelis and flycatchers.
      if (isBirdNetNonBirdClass(rawSciName)) continue;

      final SpeciesPrediction? matchedCandidate = _candidateForScientificName(
        rawSciName,
      );
      if (matchedCandidate != null) {
        // Only include if we have a valid Turkish name (not just scientific/English fallback)
        final String trName = matchedCandidate.turkishName.trim();
        final bool hasTurkishName =
            trName.isNotEmpty &&
            trName.toLowerCase() != rawSciName.toLowerCase() &&
            trName.toLowerCase() != rawEngName.toLowerCase();
        if (!hasTurkishName) {
          // No proper Turkish name — skip or use scientificName label only
          // (still add, but mark turkishName as scientificName so it's recognizable)
          predictions.add(
            matchedCandidate.copyWith(
              score: score,
              turkishName:
                  rawSciName, // show scientific name rather than English
            ),
          );
        } else {
          predictions.add(matchedCandidate.copyWith(score: score));
        }
      }
      // Labels outside the installed Türkiye candidate package must not be
      // emitted as detections. This prevents global BirdNET labels from
      // appearing as impossible local birds.
    }

    SexAgePrediction? sexAge;
    if (predictions.isNotEmpty && _policyStore != null) {
      final SpeciesSexAgePolicy policy = _policyStore!.forSpecies(
        predictions.first.speciesId,
      );
      sexAge = _sexAgeEstimator.estimate(
        speciesId: predictions.first.speciesId,
        imageFeatures: Float32List(768),
        policy: policy,
      );
    }

    debugPrint(
      'BirdNET Turkiye candidates: ${predictions.map((SpeciesPrediction item) => '${item.scientificName}=${item.score.toStringAsFixed(3)}').join(', ')}',
    );

    return InferenceResult(
      predictions: predictions,
      modelVersion: 'BirdNET-ONNX-v2.4',
      locationAffectedResult: false,
      dateAffectedResult: false,
      sourceImageUri: sourceUri,
      sexAge: sexAge,
    );
  }

  @override
  Future<ModelInformation> getModelInformation() async {
    return const ModelInformation(
      identifier: 'birdnet-onnx',
      version: 'v2.4',
      isMock: false,
    );
  }

  @override
  Future<void> dispose() async {
    _session = null;
  }

  Float32List _parseWavToFloat32(Uint8List wavBytes) {
    final Pcm16WavData? wav = parsePcm16Wav(wavBytes);
    if (wav == null || wav.sampleRate != sampleRate || wav.channels != 1) {
      return Float32List(0);
    }
    return _pcm16ToFloat32(wav.pcmBytes);
  }

  Float32List _pcm16ToFloat32(Uint8List pcmBytes) {
    final int numSamples = pcmBytes.length ~/ 2;
    final ByteData byteData = ByteData.sublistView(pcmBytes);
    final Float32List floatData = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final int intSample = byteData.getInt16(i * 2, Endian.little);
      floatData[i] = intSample / 32768.0;
    }

    return floatData;
  }

  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }
}
