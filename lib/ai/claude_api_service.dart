import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Selection of the primary AI evaluation engine for live bird identification.
enum EvaluationMode {
  /// Fast on-device inference using bundled BirdNET ONNX. Fully offline.
  local,

  /// Enriches and verifies live detections via Anthropic Claude AI API.
  claude,
}

extension EvaluationModeExtension on EvaluationMode {
  String get label => switch (this) {
    EvaluationMode.local => 'Lokal (Cihaz İçi)',
    EvaluationMode.claude => 'Claude AI (Anthropic)',
  };

  String get shortLabel => switch (this) {
    EvaluationMode.local => 'Lokal',
    EvaluationMode.claude => 'Claude AI',
  };
}

/// Structured ornithological evaluation produced by Claude API.
class ClaudeEvaluationResult {
  ClaudeEvaluationResult({
    required this.speciesScientificName,
    required this.confidenceScore,
    required this.verdict,
    required this.explanation,
    required this.isConsistent,
    this.alternativeSpecies = const <String>[],
    this.model = 'claude-3-5-haiku-20241022',
    DateTime? evaluatedAt,
  }) : evaluatedAt = evaluatedAt ?? DateTime.now();

  final String speciesScientificName;
  final double confidenceScore;
  final String verdict;
  final String explanation;
  final bool isConsistent;
  final List<String> alternativeSpecies;
  final String model;
  final DateTime evaluatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'speciesScientificName': speciesScientificName,
    'confidenceScore': confidenceScore,
    'verdict': verdict,
    'explanation': explanation,
    'isConsistent': isConsistent,
    'alternativeSpecies': alternativeSpecies,
    'model': model,
    'evaluatedAt': evaluatedAt.toIso8601String(),
  };

  factory ClaudeEvaluationResult.fromJson(Map<String, dynamic> json) {
    return ClaudeEvaluationResult(
      speciesScientificName: json['speciesScientificName'] as String? ?? '',
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      verdict: json['verdict'] as String? ?? 'Olası',
      explanation: json['explanation'] as String? ?? '',
      isConsistent: json['isConsistent'] as bool? ?? true,
      alternativeSpecies:
          (json['alternativeSpecies'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      model: json['model'] as String? ?? 'claude-3-5-haiku-20241022',
      evaluatedAt: json['evaluatedAt'] != null
          ? DateTime.tryParse(json['evaluatedAt'] as String)
          : null,
    );
  }
}

class ClaudeApiException implements Exception {
  const ClaudeApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ClaudeApiException: $message';
}

class ClaudeApiKeyMissingException implements Exception {
  const ClaudeApiKeyMissingException();

  @override
  String toString() => 'Claude API anahtarı ayarlanmamış.';
}

/// Gateway service for Anthropic Claude API integration.
///
/// Stores user API key in platform secure storage ([FlutterSecureStorage])
/// and communicates with Anthropic Messages API.
class ClaudeApiService {
  ClaudeApiService({Dio? dio, FlutterSecureStorage? storage})
    : _dio = dio ?? Dio(),
      _storage = storage ?? const FlutterSecureStorage();

  static const String _apiKeyStorageKey = 'claude_user_api_key';
  static const String defaultModel = 'claude-3-5-haiku-20241022';
  static const String _messagesUrl = 'https://api.anthropic.com/v1/messages';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<bool> hasApiKey() async => (await apiKey()) != null;

  Future<String?> apiKey() async {
    final String? value = await _storage.read(key: _apiKeyStorageKey);
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> saveApiKey(String value) async {
    final String key = value.trim();
    if (key.length < 15) {
      throw const FormatException('Geçerli bir Claude API anahtarı girin (sk-ant-...).');
    }
    await _storage.write(key: _apiKeyStorageKey, value: key);
  }

  Future<void> clearApiKey() => _storage.delete(key: _apiKeyStorageKey);

  /// Verifies [candidate] key with a lightweight Anthropic API ping.
  Future<void> testApiKey(String candidate) async {
    final String key = candidate.trim();
    if (key.length < 15) {
      throw const FormatException('Geçerli bir Claude API anahtarı girin (sk-ant-...).');
    }

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        _messagesUrl,
        data: <String, dynamic>{
          'model': defaultModel,
          'max_tokens': 10,
          'messages': <Map<String, String>>[
            <String, String>{'role': 'user', 'content': 'ping'},
          ],
        },
        options: Options(
          headers: <String, String>{
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode != 200) {
        throw ClaudeApiException(
          'Claude API doğrulanırken hata oluştu (Kod: ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 401) {
        throw const ClaudeApiException(
          'Claude API anahtarı geçersiz veya yetkisiz (401 Unauthorized).',
          statusCode: 401,
        );
      } else if (status == 429) {
        throw const ClaudeApiException(
          'Claude API istek sınırına ulaşıldı (Rate limit).',
          statusCode: 429,
        );
      } else {
        final dynamic errDetail = e.response?.data;
        final String msg = errDetail is Map && errDetail['error'] is Map
            ? errDetail['error']['message']?.toString() ?? e.message ?? 'Bağlantı hatası'
            : e.message ?? 'Claude API bağlantı hatası';
        throw ClaudeApiException(msg, statusCode: status);
      }
    }
  }

  /// Evaluates a live detection candidate using Claude's ornithology knowledge.
  Future<ClaudeEvaluationResult> evaluateLiveDetection({
    required String speciesTurkishName,
    required String speciesScientificName,
    required double modelConfidence,
    required double peakDbfs,
    required double foregroundDbfs,
    required double contrastDb,
    required DateTime moment,
    double? latitude,
    double? longitude,
    String? regionalSupport,
    String? temporalContext,
    List<String>? candidateAlternatives,
    String model = defaultModel,
  }) async {
    final String? key = await apiKey();
    if (key == null) throw const ClaudeApiKeyMissingException();

    const String systemPrompt =
        'Sen Türkiye kuş faunası (avifauna) ve biyyoakustik konusunda uzmanlaşmış bir ornitolog yapay zekasın. '
        'Mobil cihazdaki akustik sinyal modelinin canlı dinlemede tespit ettiği kuş adayını, ses kalitesini ve '
        'gözlem bağlamını (saat, tarih, bölge, eBird geçmişi) bilimsel olarak değerlendiriyorsun. '
        'Lütfen YALNIZCA geçerli bir JSON nesnesi döndür. Markdown bloğu veya başka metin ekleme. JSON şeması:\n'
        '{\n'
        '  "verdict": "Doğrulandı" | "Olası" | "Şüpheli",\n'
        '  "confidenceScore": 0.85,\n'
        '  "explanation": "Türkçe 1-2 cümlelik öz ve uzman ornitolojik açıklama.",\n'
        '  "isConsistent": true,\n'
        '  "alternativeSpecies": ["Karışabilecek türler"]\n'
        '}';

    final String userPrompt =
        'Canlı Kuş Sesi Tespiti Değerlendirmesi:\n'
        '- Tespit Edilen Tür: $speciesTurkishName ($speciesScientificName)\n'
        '- Akustik Model Güven Skoru: %${(modelConfidence * 100).round()}\n'
        '- Tespit Zamanı: ${moment.year}-${moment.month.toString().padLeft(2, '0')}-${moment.day.toString().padLeft(2, '0')} '
        '${moment.hour.toString().padLeft(2, '0')}:${moment.minute.toString().padLeft(2, '0')} (Ay: ${moment.month})\n'
        '- Konum: ${latitude != null && longitude != null ? '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)} (Türkiye)' : 'Türkiye geneli'}\n'
        '- Ses Sinyal Seviyesi: Ön plan: ${foregroundDbfs.toStringAsFixed(1)} dBFS, Tepe: ${peakDbfs.toStringAsFixed(1)} dBFS, Kontrast: ${contrastDb.toStringAsFixed(1)} dB\n'
        '- Bölgesel eBird Desteği: ${regionalSupport ?? 'Veri yok'}\n'
        '- Zaman/Mevsim Uyumu: ${temporalContext ?? 'Normal'}\n'
        '- Modeldeki Diğer Adaylar: ${candidateAlternatives != null && candidateAlternatives.isNotEmpty ? candidateAlternatives.join(', ') : 'Belirtilmedi'}\n\n'
        'Bu türün Türkiye\'deki mevsimsel bulunabilirliği, ötüş saati ve ses kalitesine göre değerlendir.';

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        _messagesUrl,
        data: <String, dynamic>{
          'model': model,
          'max_tokens': 350,
          'system': systemPrompt,
          'messages': <Map<String, String>>[
            <String, String>{'role': 'user', 'content': userPrompt},
          ],
        },
        options: Options(
          headers: <String, String>{
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final dynamic responseData = response.data;
      if (responseData is Map && responseData['content'] is List) {
        final List<dynamic> contentList = responseData['content'] as List<dynamic>;
        if (contentList.isNotEmpty && contentList.first is Map) {
          final String rawText = (contentList.first['text'] as String? ?? '').trim();
          return _parseClaudeResponse(rawText, speciesScientificName, modelConfidence, model);
        }
      }

      throw const ClaudeApiException('Claude API beklenmeyen bir yanıt döndürdü.');
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 401) {
        throw const ClaudeApiException(
          'Claude API anahtarı geçersiz veya yetkisiz (401).',
          statusCode: 401,
        );
      } else if (status == 429) {
        throw const ClaudeApiException(
          'Claude API istek kotası aşıldı (429).',
          statusCode: 429,
        );
      }
      throw ClaudeApiException(
        e.message ?? 'Claude API değerlendirmesi başarısız oldu.',
        statusCode: status,
      );
    }
  }

  ClaudeEvaluationResult _parseClaudeResponse(
    String rawText,
    String defaultScientificName,
    double defaultScore,
    String model,
  ) {
    try {
      // Find JSON block if Claude wrapped with markdown fences
      String clean = rawText;
      final int firstBrace = clean.indexOf('{');
      final int lastBrace = clean.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        clean = clean.substring(firstBrace, lastBrace + 1);
      }

      final dynamic decoded = jsonDecode(clean);
      if (decoded is Map<String, dynamic>) {
        final double score = (decoded['confidenceScore'] as num?)?.toDouble() ?? defaultScore;
        final String verdict = decoded['verdict'] as String? ?? 'Olası';
        final String explanation = decoded['explanation'] as String? ?? rawText;
        final bool isConsistent = decoded['isConsistent'] as bool? ?? true;
        final List<String> alt =
            (decoded['alternativeSpecies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const <String>[];

        return ClaudeEvaluationResult(
          speciesScientificName: defaultScientificName,
          confidenceScore: score.clamp(0.0, 1.0),
          verdict: verdict,
          explanation: explanation,
          isConsistent: isConsistent,
          alternativeSpecies: alt,
          model: model,
        );
      }
    } catch (_) {
      // Fallback: create result from raw text
    }

    return ClaudeEvaluationResult(
      speciesScientificName: defaultScientificName,
      confidenceScore: defaultScore,
      verdict: 'Olası',
      explanation: rawText.isNotEmpty ? rawText : 'Claude değerlendirmesi tamamlandı.',
      isConsistent: true,
      model: model,
    );
  }
}
