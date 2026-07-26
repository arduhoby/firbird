import 'dart:convert';
import 'dart:io';

import 'package:firbird/observation_context/ebird_context_package.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('loads a source-attributed offline Türkiye context package', () async {
    final Directory directory = await _writePackage();
    addTearDown(() => directory.delete(recursive: true));

    final EbirdContextPackage package = await EbirdContextPackage.load(
      directory,
    );

    expect(package.manifest.packageId, 'turkey-ebird-context');
    expect(package.manifest.regionCode, 'TR');
    expect(package.manifest.lookbackDays, 30);
    expect(package.manifest.sources, hasLength(2));
    expect(package.hotspots.single.name, 'Test Gözlem Noktası');
    expect(package.recentObservations.single.scientificName, 'Hirundo rustica');
  });

  test('rejects a package whose manifest count is incorrect', () async {
    final Directory directory = await _writePackage(hotspotCount: 2);
    addTearDown(() => directory.delete(recursive: true));

    expect(
      () => EbirdContextPackage.load(directory),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects invalid coordinates', () {
    expect(
      () => EbirdHotspot.fromJson(<String, dynamic>{
        'id': 'L1',
        'name': 'Invalid',
        'latitude': 91,
        'longitude': 29,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

Future<Directory> _writePackage({int hotspotCount = 1}) async {
  final Directory directory = await Directory.systemTemp.createTemp(
    'firbird-ebird-context-',
  );
  await File(path.join(directory.path, 'hotspots.json')).writeAsString(
    jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'L123',
        'name': 'Test Gözlem Noktası',
        'latitude': 40.8,
        'longitude': 29.4,
        'subnational1Code': 'TR-41',
      },
    ]),
  );
  await File(
    path.join(directory.path, 'recent_observations.json'),
  ).writeAsString(
    jsonEncode(<Map<String, dynamic>>[
      <String, dynamic>{
        'speciesCode': 'barswa',
        'scientificName': 'Hirundo rustica',
        'commonName': 'Barn Swallow',
        'locationId': 'L123',
        'locationName': 'Test Gözlem Noktası',
        'observedAt': '2026-07-26 08:30',
        'latitude': 40.8,
        'longitude': 29.4,
        'count': 2,
        'reviewed': true,
      },
    ]),
  );
  await File(path.join(directory.path, 'manifest.json')).writeAsString(
    jsonEncode(<String, dynamic>{
      'schemaVersion': 1,
      'packageId': 'turkey-ebird-context',
      'version': '2026.07.26',
      'regionCode': 'TR',
      'generatedAt': '2026-07-26T09:00:00Z',
      'lookbackDays': 30,
      'counts': <String, int>{
        'hotspots': hotspotCount,
        'recentObservations': 1,
      },
      'sources': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'eBird Hotspot API',
          'endpoint': 'https://api.ebird.org/v2/ref/hotspot/TR?fmt=json',
          'fetchedAt': '2026-07-26T09:00:00Z',
          'recordCount': 1,
        },
        <String, dynamic>{
          'name': 'eBird Recent Observations API',
          'endpoint': 'https://api.ebird.org/v2/data/obs/TR/recent',
          'fetchedAt': '2026-07-26T09:00:00Z',
          'recordCount': 1,
        },
      ],
      'files': <String, dynamic>{
        'hotspots': <String, String>{'name': 'hotspots.json'},
        'recentObservations': <String, String>{
          'name': 'recent_observations.json',
        },
      },
    }),
  );
  return directory;
}
