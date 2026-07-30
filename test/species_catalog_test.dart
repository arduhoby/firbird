import 'package:firbird/species/species_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the bundled audio catalog schema and stable species keys', () {
    final SpeciesCatalog catalog = SpeciesCatalog.fromJson(<String, dynamic>{
      'species': <Map<String, dynamic>>[
        <String, dynamic>{
          'scientificName': 'Carduelis carduelis',
          'turkishName': 'Saka',
          'englishName': 'European Goldfinch',
          'occurrence': 'resident',
          'ornitoId': '123',
          'imageUrl': 'https://example.test/saka.jpg',
        },
      ],
    });

    final SpeciesCatalogEntry? byId = catalog.find(
      speciesId: 'carduelis-carduelis',
    );
    final SpeciesCatalogEntry? byName = catalog.find(
      scientificName: '  CARDUELIS   CARDUELIS ',
    );

    expect(byId, isNotNull);
    expect(byName, same(byId));
    expect(byId!.turkishName, 'Saka');
    expect(byId.imageUrl, 'https://example.test/saka.jpg');
    expect(byId.occurrence, 'resident');
  });
}
