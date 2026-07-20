import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

class RegionPackageManifest {
  const RegionPackageManifest({
    required this.schemaVersion,
    required this.packageId,
    required this.version,
    required this.minimumAppVersion,
    required this.speciesCount,
  });

  factory RegionPackageManifest.fromJson(Map<String, Object?> json) {
    final Object? schemaVersion = json['schemaVersion'];
    final Object? packageId = json['packageId'];
    final Object? version = json['version'];
    final Object? minimumAppVersion = json['minimumAppVersion'];
    final Object? speciesCount = json['speciesCount'];
    if (schemaVersion is! int ||
        packageId is! String ||
        version is! String ||
        minimumAppVersion is! String ||
        speciesCount is! int ||
        !RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$').hasMatch(packageId)) {
      throw const PackageValidationException('Invalid package manifest.');
    }

    return RegionPackageManifest(
      schemaVersion: schemaVersion,
      packageId: packageId,
      version: version,
      minimumAppVersion: minimumAppVersion,
      speciesCount: speciesCount,
    );
  }

  final int schemaVersion;
  final String packageId;
  final String version;
  final String minimumAppVersion;
  final int speciesCount;
}

class PackageValidationException implements Exception {
  const PackageValidationException(this.message);

  final String message;
}

class RegionPackageInstaller {
  const RegionPackageInstaller({
    this.maxArchiveBytes = 50 * 1024 * 1024,
    this.maxExtractedBytes = 200 * 1024 * 1024,
    this.maxFileCount = 10000,
  });

  final int maxArchiveBytes;
  final int maxExtractedBytes;
  final int maxFileCount;

  Future<RegionPackageManifest> installFromBytes({
    required Uint8List packageBytes,
    required String expectedSha256,
    required Directory installationRoot,
  }) async {
    if (packageBytes.lengthInBytes > maxArchiveBytes) {
      throw const PackageValidationException('Package archive is too large.');
    }
    if (sha256.convert(packageBytes).toString() !=
        expectedSha256.toLowerCase()) {
      throw const PackageValidationException(
        'Package checksum does not match.',
      );
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(packageBytes, verify: true);
    } catch (_) {
      throw const PackageValidationException('Package archive is invalid.');
    }
    _validateArchive(archive);
    final ArchiveFile manifestFile = _findManifest(archive);
    final RegionPackageManifest manifest = _parseManifest(manifestFile);

    await installationRoot.create(recursive: true);
    final Directory staging = Directory(
      path.join(
        installationRoot.path,
        <String>['.', manifest.packageId, 'staging'].join(),
      ),
    );
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);

    try {
      for (final ArchiveFile file in archive.files) {
        if (!file.isFile) {
          continue;
        }
        final File destination = File(path.join(staging.path, file.name));
        await destination.parent.create(recursive: true);
        await destination.writeAsBytes(file.content as List<int>, flush: true);
      }
      await _atomicInstall(
        staging: staging,
        target: Directory(path.join(installationRoot.path, manifest.packageId)),
      );
    } catch (_) {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }

    return manifest;
  }

  ArchiveFile _findManifest(Archive archive) {
    for (final ArchiveFile file in archive.files) {
      if (file.isFile && file.name == 'manifest.json') {
        return file;
      }
    }
    throw const PackageValidationException('Package manifest is missing.');
  }

  void _validateArchive(Archive archive) {
    if (archive.files.length > maxFileCount) {
      throw const PackageValidationException(
        'Package contains too many files.',
      );
    }
    int totalSize = 0;
    for (final ArchiveFile file in archive.files) {
      final String normalized = path.normalize(file.name);
      if (path.isAbsolute(file.name) ||
          normalized == '..' ||
          normalized.startsWith(<String>['..', path.separator].join())) {
        throw const PackageValidationException(
          'Package contains an unsafe path.',
        );
      }
      totalSize += file.size;
      if (totalSize > maxExtractedBytes) {
        throw const PackageValidationException(
          'Package expands beyond the allowed size.',
        );
      }
    }
  }

  RegionPackageManifest _parseManifest(ArchiveFile file) {
    try {
      final Object? decoded = jsonDecode(
        utf8.decode(file.content as List<int>),
      );
      if (decoded is! Map<String, Object?>) {
        throw const PackageValidationException('Package manifest is invalid.');
      }
      return RegionPackageManifest.fromJson(decoded);
    } on FormatException {
      throw const PackageValidationException('Package manifest is invalid.');
    }
  }

  Future<void> _atomicInstall({
    required Directory staging,
    required Directory target,
  }) async {
    final Directory backup = Directory(
      <String>[target.path, 'backup'].join('.'),
    );
    if (await backup.exists()) {
      await backup.delete(recursive: true);
    }
    if (await target.exists()) {
      await target.rename(backup.path);
    }
    try {
      await staging.rename(target.path);
      if (await backup.exists()) {
        await backup.delete(recursive: true);
      }
    } catch (_) {
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }
}
