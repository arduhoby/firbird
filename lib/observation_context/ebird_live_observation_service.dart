import 'package:dio/dio.dart';
import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores a user-owned eBird key in the platform secure store and requests
/// current data only after the user explicitly asks to refresh a hotspot.
class EbirdLiveObservationService {
  EbirdLiveObservationService({Dio? dio, FlutterSecureStorage? storage})
    : _dio = dio ?? Dio(),
      _storage = storage ?? const FlutterSecureStorage();

  static const String _apiKeyStorageKey = 'ebird_user_api_key';

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
    if (key.length < 8 || key.length > 128) {
      throw const FormatException('Geçerli bir eBird API anahtarı girin.');
    }
    await _storage.write(key: _apiKeyStorageKey, value: key);
  }

  Future<void> clearApiKey() => _storage.delete(key: _apiKeyStorageKey);

  Future<void> testApiKey(String candidate) async {
    final String key = candidate.trim();
    if (key.length < 8 || key.length > 128) {
      throw const FormatException('Geçerli bir eBird API anahtarı girin.');
    }
    await _request(
      'https://api.ebird.org/v2/data/obs/geo/recent',
      key: key,
      queryParameters: const <String, dynamic>{
        'lat': 39.0,
        'lng': 35.0,
        'dist': 1,
        'maxResults': 1,
      },
    );
  }

  Future<List<EbirdRecentObservation>> refreshHotspot(
    String locationId,
  ) async {
    final String? key = await apiKey();
    if (key == null) throw const EbirdApiKeyMissingException();

    final dynamic data = await _request(
      'https://api.ebird.org/v2/data/obs/$locationId/recent',
      key: key,
      queryParameters: const <String, dynamic>{
          'back': 30,
          'includeProvisional': false,
          'maxResults': 10000,
          'sppLocale': 'tr',
      },
    );
    return _observationsFromResponse(data);
  }

  Future<List<EbirdRecentObservation>> refreshNearby({
    required double latitude,
    required double longitude,
    required int radiusKm,
  }) async {
    final String? key = await apiKey();
    if (key == null) throw const EbirdApiKeyMissingException();
    final dynamic data = await _request(
      'https://api.ebird.org/v2/data/obs/geo/recent',
      key: key,
      queryParameters: <String, dynamic>{
        'lat': latitude.toStringAsFixed(4),
        'lng': longitude.toStringAsFixed(4),
        'dist': radiusKm.clamp(1, 50),
        'back': 30,
        'hotspot': true,
        'includeProvisional': false,
        'maxResults': 10000,
        'sppLocale': 'tr',
      },
    );
    return _observationsFromResponse(data);
  }

  Future<dynamic> _request(
    String url, {
    required String key,
    required Map<String, dynamic> queryParameters,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: <String, String>{'X-eBirdApiToken': key},
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
        ),
      );
      return response.data;
    } on DioException catch (error) {
      final int? status = error.response?.statusCode;
      if (status == 401 || status == 403) {
        throw const EbirdLiveDataException('eBird API anahtarı kabul edilmedi.');
      }
      if (status == 429) {
        throw const EbirdLiveDataException(
          'eBird istek sınırına ulaşıldı; biraz sonra tekrar deneyin.',
        );
      }
      throw const EbirdLiveDataException(
        'Güncel eBird verisi alınamadı. İnternet bağlantısını kontrol edin.',
      );
    }
  }

  List<EbirdRecentObservation> _observationsFromResponse(dynamic data) {
    if (data is! List<dynamic>) {
      throw const EbirdLiveDataException('eBird beklenmeyen bir yanıt verdi.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(_observationFromApi)
        .toList(growable: false);
  }

  EbirdRecentObservation _observationFromApi(Map<String, dynamic> value) {
    final String commonName = value['comName'] as String? ?? 'Bilinmeyen tür';
    return EbirdRecentObservation.fromJson(<String, dynamic>{
      'speciesCode': value['speciesCode'] as String? ?? 'unknown',
      'scientificName': value['sciName'] as String? ?? commonName,
      'commonName': commonName,
      'turkishName': commonName,
      'locationId': value['locId'] as String? ?? 'unknown',
      'locationName': value['locName'] as String? ?? 'Bilinmeyen nokta',
      'observedAt': value['obsDt'] as String? ?? DateTime.now().toIso8601String(),
      'latitude': value['lat'] as num? ?? 0,
      'longitude': value['lng'] as num? ?? 0,
      'count': value['howMany'] as num?,
      'reviewed': value['obsReviewed'] as bool? ?? false,
      'submissionId': value['subId'] as String?,
      'observerName': value['userDisplayName'] as String?,
      'isLive': true,
    });
  }
}

class EbirdApiKeyMissingException implements Exception {
  const EbirdApiKeyMissingException();
}

class EbirdLiveDataException implements Exception {
  const EbirdLiveDataException(this.message);

  final String message;
}
