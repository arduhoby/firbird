import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:firbird/region_packages/region_package_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('installs a checksum-verified package', () async {
    final Uint8List packageBytes = _packageBytes();
    final Directory root = await Directory.systemTemp.createTemp(
      'firbird-test',
    );
    addTearDown(() => root.delete(recursive: true));

    final RegionPackageManifest manifest = await const RegionPackageInstaller()
        .installFromBytes(
          packageBytes: packageBytes,
          expectedSha256: sha256.convert(packageBytes).toString(),
          installationRoot: root,
        );

    expect(manifest.packageId, 'turkey-all');
    expect(
      File(path.join(root.path, 'turkey-all', 'manifest.json')).existsSync(),
      isTrue,
    );
  });

  test('rejects a mismatched checksum', () async {
    final Uint8List packageBytes = _packageBytes();
    final Directory root = await Directory.systemTemp.createTemp(
      'firbird-test',
    );
    addTearDown(() => root.delete(recursive: true));

    expect(
      () => const RegionPackageInstaller().installFromBytes(
        packageBytes: packageBytes,
        expectedSha256: 'not-a-checksum',
        installationRoot: root,
      ),
      throwsA(isA<PackageValidationException>()),
    );
  });
}

Uint8List _packageBytes() {
  final List<int> manifest = utf8.encode(
    jsonEncode(<String, Object>{
      'schemaVersion': 1,
      'packageId': 'turkey-all',
      'version': '0.1.0',
      'minimumAppVersion': '0.1.0',
      'speciesCount': 0,
    }),
  );
  final Archive archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
  return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
}
