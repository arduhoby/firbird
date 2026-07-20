import 'package:firbird/region_packages/release_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a GitHub Release compatible catalog', () {
    final ReleaseCatalog catalog = ReleaseCatalog.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'generatedAt': '2026-07-19T00:00:00Z',
      'packages': <Object?>[
        <String, Object?>{
          'id': 'turkey-all',
          'version': '1.0.0',
          'downloadUrl':
              'https://github.com/example/firbird/releases/download/v1/turkey-all.firbird',
          'sha256': 'abc',
          'sizeBytes': 12,
        },
      ],
    });

    expect(catalog.packages.single.id, 'turkey-all');
    expect(compareSemVer('1.1.0', '1.0.9'), greaterThan(0));
  });

  test('parses optional package coverage and compatibility metadata', () {
    final ReleaseCatalog catalog = ReleaseCatalog.fromJson(<String, Object?>{
      'schemaVersion': 1,
      'generatedAt': '2026-07-20T00:00:00Z',
      'packages': <Object?>[
        <String, Object?>{
          'id': 'balkans',
          'version': '0.1.0',
          'downloadUrl': 'https://example.test/balkans.firbird',
          'sha256': 'abc',
          'sizeBytes': 12,
          'coverage': <Object?>['BG', 'GR'],
          'originScope': 'balkanlar',
          'modelId': 'turkey-bioclip2-int8',
        },
      ],
    });

    final CatalogPackage package = catalog.packages.single;
    expect(package.coverage, <String>['BG', 'GR']);
    expect(package.originScope, 'balkanlar');
    expect(package.modelId, 'turkey-bioclip2-int8');
  });
}
