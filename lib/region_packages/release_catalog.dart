import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

class ReleaseCatalog {
  const ReleaseCatalog({
    required this.schemaVersion,
    required this.generatedAt,
    required this.packages,
  });

  factory ReleaseCatalog.fromJson(Map<String, Object?> json) {
    final Object? schemaVersion = json['schemaVersion'];
    final Object? generatedAt = json['generatedAt'];
    final Object? packages = json['packages'];
    if (schemaVersion is! int ||
        generatedAt is! String ||
        packages is! List<Object?>) {
      throw const CatalogException('Catalog format is invalid.');
    }
    return ReleaseCatalog(
      schemaVersion: schemaVersion,
      generatedAt: DateTime.parse(generatedAt),
      packages: packages
          .map(
            (Object? entry) =>
                CatalogPackage.fromJson(entry! as Map<String, Object?>),
          )
          .toList(growable: false),
    );
  }

  final int schemaVersion;
  final DateTime generatedAt;
  final List<CatalogPackage> packages;
}

class CatalogPackage {
  const CatalogPackage({
    required this.id,
    required this.version,
    required this.downloadUrl,
    required this.sha256,
    required this.sizeBytes,
    this.coverage = const <String>[],
    this.originScope,
    this.modelId,
  });

  factory CatalogPackage.fromJson(Map<String, Object?> json) {
    final Object? id = json['id'];
    final Object? version = json['version'];
    final Object? downloadUrl = json['downloadUrl'];
    final Object? sha256 = json['sha256'];
    final Object? sizeBytes = json['sizeBytes'];
    final Object? coverage = json['coverage'];
    final Object? originScope = json['originScope'];
    final Object? modelId = json['modelId'];
    if (id is! String ||
        version is! String ||
        downloadUrl is! String ||
        sha256 is! String ||
        sizeBytes is! int ||
        (coverage != null && coverage is! List<Object?>) ||
        (originScope != null && originScope is! String) ||
        (modelId != null && modelId is! String) ||
        Uri.tryParse(downloadUrl)?.hasScheme != true) {
      throw const CatalogException('Catalog package entry is invalid.');
    }
    return CatalogPackage(
      id: id,
      version: version,
      downloadUrl: Uri.parse(downloadUrl),
      sha256: sha256.toLowerCase(),
      sizeBytes: sizeBytes,
      coverage: coverage == null
          ? const <String>[]
          : (coverage as List<Object?>).cast<String>(),
      originScope: originScope as String?,
      modelId: modelId as String?,
    );
  }

  final String id;
  final String version;
  final Uri downloadUrl;
  final String sha256;
  final int sizeBytes;
  final List<String> coverage;
  final String? originScope;
  final String? modelId;
}

class CatalogException implements Exception {
  const CatalogException(this.message);

  final String message;
}

class GitHubReleaseCatalogClient {
  GitHubReleaseCatalogClient({required this.catalogUrl, Dio? dio})
    : _dio = dio ?? Dio();

  final Uri catalogUrl;
  final Dio _dio;

  Future<ReleaseCatalog> fetch() async {
    try {
      final Response<String> response = await _dio.get<String>(
        catalogUrl.toString(),
        options: Options(responseType: ResponseType.plain),
      );
      final Object? decoded = jsonDecode(response.data!);
      if (decoded is! Map<String, Object?>) {
        throw const CatalogException('Catalog format is invalid.');
      }
      return ReleaseCatalog.fromJson(decoded);
    } on DioException {
      throw const CatalogException('Catalog is unavailable.');
    } on FormatException {
      throw const CatalogException('Catalog format is invalid.');
    }
  }
}

class ResumablePackageDownloader {
  ResumablePackageDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<File> download({
    required CatalogPackage package,
    required File temporaryFile,
    ProgressCallback? onReceiveProgress,
  }) async {
    final int existingBytes = await temporaryFile.exists()
        ? await temporaryFile.length()
        : 0;
    final Map<String, Object> headers = <String, Object>{
      if (existingBytes > 0) 'Range': 'bytes=$existingBytes-',
    };
    final Response<ResponseBody> response = await _dio.get<ResponseBody>(
      package.downloadUrl.toString(),
      options: Options(
        headers: headers,
        responseType: ResponseType.stream,
        validateStatus: (int? status) => status == 200 || status == 206,
      ),
    );
    final bool isPartial = response.statusCode == 206 && existingBytes > 0;
    await temporaryFile.parent.create(recursive: true);
    final IOSink sink = temporaryFile.openWrite(
      mode: isPartial ? FileMode.append : FileMode.write,
    );
    final int totalBytes = response.data!.contentLength;
    int receivedBytes = 0;
    try {
      await for (final List<int> chunk in response.data!.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        onReceiveProgress?.call(
          existingBytes + receivedBytes,
          totalBytes < 0 ? -1 : existingBytes + totalBytes,
        );
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return temporaryFile;
  }
}

int compareSemVer(String left, String right) {
  final List<int> leftParts = _parseSemVer(left);
  final List<int> rightParts = _parseSemVer(right);
  for (int index = 0; index < 3; index++) {
    if (leftParts[index] != rightParts[index]) {
      return leftParts[index].compareTo(rightParts[index]);
    }
  }
  return 0;
}

List<int> _parseSemVer(String version) {
  final List<String> parts = version
      .split('+')
      .first
      .split('-')
      .first
      .split('.');
  if (parts.length != 3) {
    throw const CatalogException('Version is not semantic versioning.');
  }
  return parts.map(int.parse).toList(growable: false);
}
