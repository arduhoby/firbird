import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:audio_decoder/audio_decoder.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class AudioInput {
  const AudioInput({required this.uri});
  final String uri;
}

class AudioInferenceEngine implements BirdInferenceEngine {
  AudioInferenceEngine({required this.modelPath, required this.labelsPath});

  final String modelPath;
  final String labelsPath;
  List<String> _labels = [];
  
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
    
    // Initialize ONNX runtime if needed (package does this automatically or doesn't need it)
    
    // Create session
    _session = await _runtime.createSession(modelPath);
    
    // Load labels
    final File labelsFile = File(labelsPath);
    if (await labelsFile.exists()) {
      _labels = await labelsFile.readAsLines();
    } else {
      debugPrint('Labels file not found at $labelsPath');
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
        
        offset += chunkSize; // non-overlapping windows. Could use overlapping for better results.
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
        // Label is usually "Scientific_Name_Common_Name". Let's mock the split for now.
        final parts = label.split('_');
        final String scientificName = parts.length > 1 ? '${parts[0]} ${parts[1]}' : label;
        
        predictions.add(
          SpeciesPrediction(
            speciesId: 'birdnet-$index',
            turkishName: label, // We will need a proper translation map
            scientificName: scientificName,
            englishName: label,
            score: score,
          ),
        );
      }
      
      return InferenceResult(
        predictions: predictions,
        modelVersion: 'BirdNET-ONNX-v2.4',
        locationAffectedResult: false,
        dateAffectedResult: false,
        sourceImageUri: audio.uri,
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
    // Basic WAV parsing assuming 16-bit PCM, 44-byte header
    // In a real app, parse the RIFF header properly to find the data chunk.
    const int headerSize = 44;
    if (wavBytes.length <= headerSize) {
      return Float32List(0);
    }
    
    final int dataSize = wavBytes.length - headerSize;
    final int numSamples = dataSize ~/ 2; // 16-bit = 2 bytes per sample
    
    final ByteData byteData = ByteData.sublistView(wavBytes, headerSize);
    final Float32List floatData = Float32List(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
      final int intSample = byteData.getInt16(i * 2, Endian.little);
      // Normalize to [-1.0, 1.0]
      floatData[i] = intSample / 32768.0;
    }
    
    return floatData;
  }

  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }
}
