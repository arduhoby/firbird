import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audio_decoder/audio_decoder.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'bird_inference_engine.dart';
import 'onnx_bird_inference_engine.dart';
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
  SpeciesSexAgePolicyStore? _policyStore;
  final SexAgeEstimator _sexAgeEstimator = const PlaceholderSexAgeEstimator();
  
  final OnnxRuntime _runtime = OnnxRuntime();
  OrtSession? _session;
  bool _isWarmedUp = false;
  
  static const int sampleRate = 48000;
  static const int chunkDurationSeconds = 3;
  static const int chunkSize = sampleRate * chunkDurationSeconds; // 144,000 samples

  @override
  List<SpeciesPrediction> get candidateSpecies => []; // Populate later if needed

  @override
  Future<void> warmUp() async {
    if (_isWarmedUp) return;
    
    final File modelFile = File(modelPath);
    if (!await modelFile.exists()) {
      try {
        final Directory parent = modelFile.parent;
        if (!await parent.exists()) await parent.create(recursive: true);
        final ByteData bytes = await rootBundle.load('assets/models/birdnet.onnx');
        await modelFile.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), flush: true);
      } catch (e) {
        debugPrint('Could not extract birdnet.onnx from assets: $e');
      }
    }
    
    final File labelsFile = File(labelsPath);
    if (!await labelsFile.exists()) {
      try {
        final Directory parent = labelsFile.parent;
        if (!await parent.exists()) await parent.create(recursive: true);
        final ByteData bytes = await rootBundle.load('assets/models/birdnet_labels.txt');
        await labelsFile.writeAsBytes(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), flush: true);
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

    // Load regional candidates mapping for Turkish names, origin labels, thumbnail URLs
    try {
      final Directory directory = await OnnxBirdInferenceEngine.ensureTurkeyPackageInstalled();
      final File candidatesFile = File(path.join(directory.path, 'candidates.json'));
      if (await candidatesFile.exists()) {
        final String content = (await candidatesFile.readAsString()).replaceAll('\uFEFF', '');
        final Map<String, dynamic> source = jsonDecode(content) as Map<String, dynamic>;
        final List<dynamic> jsonList = source['candidates'] as List<dynamic>;
        _candidatesByScientificName = {};
        for (final item in jsonList) {
          final candidateMap = item as Map<String, dynamic>;
          final String sciName = (candidateMap['scientificName'] as String).toLowerCase();
          final String turkishName = candidateMap['turkishName'] as String? ?? '';
          final String englishName = candidateMap['englishName'] as String? ?? '';
          final String occurrence = candidateMap['occurrence'] as String? ?? '';
          final String? imageUrl = candidateMap['imageUrl'] as String?;
          final String? ornitoId = candidateMap['ornitoId'] as String?;
          final String sciNameOriginal = candidateMap['scientificName'] as String;

          final String originLabel = switch (occurrence) {
            'accidental' => 'Türkiye · nadir kayıt',
            'regular-or-migratory' => 'Türkiye · düzenli / göçmen',
            'resident' => 'Türkiye · yerleşik',
            'balkans' => 'Balkanlar kapsamı',
            _ => occurrence.isNotEmpty ? occurrence : 'Türkiye · kayıtlı',
          };

          _candidatesByScientificName![sciName] = SpeciesPrediction(
            speciesId: sciName.replaceAll(' ', '-'),
            turkishName: turkishName.trim().isEmpty ? sciNameOriginal : turkishName,
            scientificName: sciNameOriginal,
            englishName: englishName.trim().isEmpty ? sciNameOriginal : englishName,
            score: 0.0,
            thumbnailUrl: imageUrl,
            ornitoId: ornitoId,
            originLabel: originLabel,
          );
        }
      }
    } catch (e) {
      debugPrint('Could not load candidates.json for AudioInferenceEngine: $e');
    }

    try {
      _policyStore = await SpeciesSexAgePolicyStore.load();
    } catch (e) {
      debugPrint('Could not load policy store for AudioInferenceEngine: $e');
    }
    
    _isWarmedUp = true;
  }
  
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
    final String tempWavPath = '${sourceFile.parent.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
    
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
      
      // 4. Split into chunks and run inference
      final Map<int, double> maxProbabilities = {}; // speciesIndex -> max probability across chunks
      
      int offset = 0;
      while (offset + chunkSize <= pcmData.length) {
        final Float32List chunk = Float32List.sublistView(pcmData, offset, offset + chunkSize);
        
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
          final List<double> logits = outputData.cast<num>().map((num val) => val.toDouble()).toList();
          
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
      final List<MapEntry<int, double>> sortedProbs = maxProbabilities.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
        
      final List<SpeciesPrediction> predictions = [];
      for (final entry in sortedProbs.take(5)) {
        final int index = entry.key;
        final double score = entry.value;
        
        if (score < 0.05) continue; // Noise threshold
        
        final String label = index < _labels.length ? _labels[index] : 'Unknown-$index';
        
        // BirdNET labels format: "Scientific_Name_Common_Name" or "Scientific Name_Common Name"
        final int underscoreIdx = label.indexOf('_');
        String rawSciName = label;
        String rawEngName = label;
        if (underscoreIdx != -1) {
          rawSciName = label.substring(0, underscoreIdx).trim().replaceAll('_', ' ');
          rawEngName = label.substring(underscoreIdx + 1).trim().replaceAll('_', ' ');
        } else {
          rawSciName = label.replaceAll('_', ' ');
          rawEngName = rawSciName;
        }

        // ── Non-bird / background class filter ──────────────────────────────
        // BirdNET contains non-bird sounds; skip them all
        final String sciLower = rawSciName.toLowerCase();
        final String engLower = rawEngName.toLowerCase();
        const List<String> nonBirdKeywords = [
          'human', 'homo sapien', 'dog', 'canis lupus', 'cat', 'felis catus',
          'engine', 'car', 'machinery', 'wind', 'rain', 'thunder', 'noise',
          'insect', 'frog', 'rana', 'bufo', 'cricket', 'cicada',
          'firework', 'gunshot', 'siren', 'music', 'speech',
        ];
        if (nonBirdKeywords.any((kw) => sciLower.contains(kw) || engLower.contains(kw))) {
          continue; // skip — not a bird
        }
        // ────────────────────────────────────────────────────────────────────

        final SpeciesPrediction? matchedCandidate = _candidatesByScientificName?[rawSciName.toLowerCase()];
        if (matchedCandidate != null) {
          // Only include if we have a valid Turkish name (not just scientific/English fallback)
          final String trName = matchedCandidate.turkishName.trim();
          final bool hasTurkishName = trName.isNotEmpty &&
              trName.toLowerCase() != rawSciName.toLowerCase() &&
              trName.toLowerCase() != rawEngName.toLowerCase();
          if (!hasTurkishName) {
            // No proper Turkish name — skip or use scientificName label only
            // (still add, but mark turkishName as scientificName so it's recognizable)
            predictions.add(matchedCandidate.copyWith(
              score: score,
              turkishName: rawSciName, // show scientific name rather than English
            ));
          } else {
            predictions.add(matchedCandidate.copyWith(score: score));
          }
        } else {
          // Not in candidates.json at all — likely a non-Turkey or non-bird species
          // Only include if it looks like a real bird (two-part scientific name)
          final bool looksLikeBird = rawSciName.contains(' ') &&
              !nonBirdKeywords.any((kw) => sciLower.contains(kw));
          if (!looksLikeBird) continue;

          predictions.add(
            SpeciesPrediction(
              speciesId: rawSciName.toLowerCase().replaceAll(' ', '-'),
              turkishName: rawSciName, // show scientific name — no Turkish available
              scientificName: rawSciName,
              englishName: rawEngName,
              score: score,
              originLabel: 'Dünya Türü',
            ),
          );
        }
      }
      
      SexAgePrediction? sexAge;
      if (predictions.isNotEmpty && _policyStore != null) {
        final SpeciesSexAgePolicy policy = _policyStore!.forSpecies(predictions.first.speciesId);
        sexAge = _sexAgeEstimator.estimate(
          speciesId: predictions.first.speciesId,
          imageFeatures: Float32List(768),
          policy: policy,
        );
      }

      return InferenceResult(
        predictions: predictions,
        modelVersion: 'BirdNET-ONNX-v2.4',
        locationAffectedResult: false,
        dateAffectedResult: false,
        sourceImageUri: audio.uri,
        sexAge: sexAge,
      );
      
    } finally {
      // Cleanup temporary WAV file
      final File tempFile = File(tempWavPath);
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    }
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
    const int headerSize = 44;
    if (wavBytes.length <= headerSize) {
      return Float32List(0);
    }
    
    final int dataSize = wavBytes.length - headerSize;
    final int numSamples = dataSize ~/ 2;
    
    final ByteData byteData = ByteData.sublistView(wavBytes, headerSize);
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
