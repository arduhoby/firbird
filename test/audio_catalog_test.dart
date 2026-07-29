import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BirdNET audio catalog contains the Turkish bee-eater', () async {
    final Map<String, dynamic> catalog =
        jsonDecode(
              await File(
                'assets/audio_catalog/turkey-birdnet-v1.json',
              ).readAsString(),
            )
            as Map<String, dynamic>;
    final List<dynamic> species = catalog['species'] as List<dynamic>;

    expect(catalog['id'], 'turkey-birdnet-audio');
    expect(catalog['matchedBirdNetSpeciesCount'], species.length);
    expect(species.length, greaterThanOrEqualTo(350));
    expect(
      species.any(
        (dynamic entry) =>
            (entry as Map<String, dynamic>)['scientificName'] ==
            'Merops apiaster',
      ),
      isTrue,
    );
    final Map<String, dynamic> rockDove = species
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (Map<String, dynamic> entry) =>
              entry['scientificName'] == 'Columba livia',
        );
    expect(rockDove['turkishName'], 'Kaya G\u00FCvercini');
  });
}
