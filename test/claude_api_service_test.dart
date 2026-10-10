import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:firbird/ai/claude_api_service.dart';
import 'package:firbird/data/app_database.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeStorage implements FlutterSecureStorage {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _data.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDioAdapter implements HttpClientAdapter {
  _FakeDioAdapter(this._handler);
  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('ClaudeEvaluationResult', () {
    test('serializes and deserializes correctly', () {
      final ClaudeEvaluationResult result = ClaudeEvaluationResult(
        speciesScientificName: 'Turdus merula',
        confidenceScore: 0.88,
        verdict: 'Doğrulandı',
        explanation: 'Türkiye ornitolojisi için tipik bir ötüş.',
        isConsistent: true,
        alternativeSpecies: const <String>['Turdus philomelos'],
      );

      final Map<String, dynamic> json = result.toJson();
      final ClaudeEvaluationResult decoded = ClaudeEvaluationResult.fromJson(json);

      expect(decoded.speciesScientificName, 'Turdus merula');
      expect(decoded.confidenceScore, 0.88);
      expect(decoded.verdict, 'Doğrulandı');
      expect(decoded.explanation, 'Türkiye ornitolojisi için tipik bir ötüş.');
      expect(decoded.isConsistent, isTrue);
      expect(decoded.alternativeSpecies, <String>['Turdus philomelos']);
    });
  });

  group('ClaudeApiService', () {
    late _FakeStorage storage;
    late Dio dio;

    setUp(() {
      storage = _FakeStorage();
      dio = Dio();
    });

    test('validates and saves API key securely', () async {
      final ClaudeApiService service = ClaudeApiService(dio: dio, storage: storage);

      expect(await service.hasApiKey(), isFalse);
      expect(await service.apiKey(), isNull);

      expect(
        () => service.saveApiKey('short'),
        throwsA(isA<FormatException>()),
      );

      await service.saveApiKey('sk-ant-api03-valid-test-key-123456789');
      expect(await service.hasApiKey(), isTrue);
      expect(await service.apiKey(), 'sk-ant-api03-valid-test-key-123456789');

      await service.clearApiKey();
      expect(await service.hasApiKey(), isFalse);
    });

    test('testApiKey succeeds on HTTP 200 response', () async {
      dio.httpClientAdapter = _FakeDioAdapter((RequestOptions options) async {
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'id': 'msg_123',
            'type': 'message',
            'content': <dynamic>[
              <String, dynamic>{'type': 'text', 'text': 'pong'},
            ],
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });

      final ClaudeApiService service = ClaudeApiService(dio: dio, storage: storage);
      await service.testApiKey('sk-ant-api03-valid-test-key-123456789');
    });

    test('testApiKey throws ClaudeApiException on HTTP 401 Unauthorized', () async {
      dio.httpClientAdapter = _FakeDioAdapter((RequestOptions options) async {
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'type': 'error',
            'error': <String, dynamic>{'type': 'authentication_error', 'message': 'Invalid API Key'},
          }),
          401,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });

      final ClaudeApiService service = ClaudeApiService(dio: dio, storage: storage);
      expect(
        () => service.testApiKey('sk-ant-api03-invalid-test-key'),
        throwsA(isA<ClaudeApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('evaluateLiveDetection parses Claude ornithological JSON response', () async {
      await storage.write(key: 'claude_user_api_key', value: 'sk-ant-api03-valid-key-999');

      dio.httpClientAdapter = _FakeDioAdapter((RequestOptions options) async {
        final Map<String, dynamic> claudeResponse = <String, dynamic>{
          'id': 'msg_456',
          'type': 'message',
          'content': <dynamic>[
            <String, dynamic>{
              'type': 'text',
              'text': jsonEncode(<String, dynamic>{
                'verdict': 'Doğrulandı',
                'confidenceScore': 0.92,
                'explanation': 'Karatavuk ötüşü ile ilkbahar saatleri tam uyumlu.',
                'isConsistent': true,
                'alternativeSpecies': <String>['Ördek'],
              }),
            },
          ],
        };
        return ResponseBody.fromString(
          jsonEncode(claudeResponse),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });

      final ClaudeApiService service = ClaudeApiService(dio: dio, storage: storage);
      final ClaudeEvaluationResult evaluation = await service.evaluateLiveDetection(
        speciesTurkishName: 'Karatavuk',
        speciesScientificName: 'Turdus merula',
        modelConfidence: 0.85,
        peakDbfs: -12.0,
        foregroundDbfs: -20.0,
        contrastDb: 18.0,
        moment: DateTime(2026, 5, 10, 7, 30),
      );

      expect(evaluation.speciesScientificName, 'Turdus merula');
      expect(evaluation.confidenceScore, 0.92);
      expect(evaluation.verdict, 'Doğrulandı');
      expect(evaluation.explanation, contains('Karatavuk'));
      expect(evaluation.isConsistent, isTrue);
    });
  });

  group('EvaluationMode Database Persistence', () {
    test('defaults to local and updates correctly', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await db.evaluationMode(), 'local');
      await db.setEvaluationMode('claude');
      expect(await db.evaluationMode(), 'claude');

      expect(await db.claudeApiKeyLastVerifiedAt(), isNull);
      final DateTime now = DateTime.now();
      await db.setClaudeApiKeyLastVerifiedAt(now);
      final DateTime? verified = await db.claudeApiKeyLastVerifiedAt();
      expect(verified, isNotNull);
      expect(verified!.difference(now).inSeconds.abs(), lessThanOrEqualTo(1));

      await db.clearClaudeApiKeyLastVerifiedAt();
      expect(await db.claudeApiKeyLastVerifiedAt(), isNull);
    });
  });
}
