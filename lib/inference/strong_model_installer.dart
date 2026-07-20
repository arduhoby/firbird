import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../region_packages/release_catalog.dart';
import 'strong_model_catalog.dart';

/// Downloads a strong model safely without holding the model in memory.
///
/// A partially downloaded `.part` file is intentionally retained so the next
/// attempt can resume with an HTTP Range request.
class StrongModelInstaller {
  StrongModelInstaller({ResumablePackageDownloader? downloader})
    : _downloader = downloader ?? ResumablePackageDownloader();

  final ResumablePackageDownloader _downloader;

  Future<File> install({
    required StrongModelDescriptor descriptor,
    required Directory modelsDirectory,
    ProgressCallback? onReceiveProgress,
  }) async {
    final Directory versionDirectory = Directory(
      path.join(modelsDirectory.path, descriptor.id, descriptor.version),
    );
    final File modelFile = File(path.join(versionDirectory.path, 'model.onnx'));
    final File partialFile = File('${modelFile.path}.part');

    if (await modelFile.exists() && await _isVerified(modelFile, descriptor)) {
      return modelFile;
    }

    final CatalogPackage package = CatalogPackage(
      id: descriptor.id,
      version: descriptor.version,
      downloadUrl: descriptor.modelUri,
      sha256: descriptor.sha256,
      sizeBytes: descriptor.modelBytes,
    );
    await _downloader.download(
      package: package,
      temporaryFile: partialFile,
      onReceiveProgress: onReceiveProgress,
    );
    if (!await _isVerified(partialFile, descriptor)) {
      throw const StrongModelInstallException(
        'Model indirildi ancak doğrulaması geçmedi. İndirme kaldığı yerden yeniden denenecek.',
      );
    }

    await versionDirectory.create(recursive: true);
    if (await modelFile.exists()) {
      await modelFile.delete();
    }
    await partialFile.rename(modelFile.path);
    return modelFile;
  }

  Future<bool> _isVerified(File file, StrongModelDescriptor descriptor) async {
    if (!await file.exists() || await file.length() != descriptor.modelBytes) {
      return false;
    }
    final Digest digest = await sha256.bind(file.openRead()).first;
    return digest.toString().toLowerCase() == descriptor.sha256.toLowerCase();
  }
}

class StrongModelInstallException implements Exception {
  const StrongModelInstallException(this.message);

  final String message;
}
