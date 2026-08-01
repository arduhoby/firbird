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

  test('resolves taxonomy synonyms, slash entries, and genus fallbacks', () {
    final SpeciesCatalog catalog = SpeciesCatalog.fromJson(<String, dynamic>{
      'species': <Map<String, dynamic>>[
        <String, dynamic>{
          'scientificName': 'Sylvia communis',
          'turkishName': 'Akgerdanlı Ötleyen',
          'englishName': 'Common Whitethroat',
          'imageUrl': 'https://example.test/whitethroat.jpg',
        },
        <String, dynamic>{
          'scientificName': 'Apus apus',
          'turkishName': 'Ebubekir',
          'englishName': 'Common Swift',
          'imageUrl': 'https://example.test/swift.jpg',
        },
        <String, dynamic>{
          'scientificName': 'Buteo buteo',
          'turkishName': 'Şahin',
          'englishName': 'Common Buzzard',
          'imageUrl': 'https://example.test/buzzard.jpg',
        },
      ],
    });

    // Genus synonym: Curruca -> Sylvia
    final SpeciesCatalogEntry? curruca = catalog.find(
      scientificName: 'Curruca communis',
    );
    expect(curruca, isNotNull);
    expect(curruca!.scientificName, 'Sylvia communis');

    // Slash entry: Apus apus/pallidus -> Apus apus
    final SpeciesCatalogEntry? slash = catalog.find(
      scientificName: 'Apus apus/pallidus',
    );
    expect(slash, isNotNull);
    expect(slash!.scientificName, 'Apus apus');

    // Genus sp. fallback: Buteo sp. -> Buteo buteo
    final SpeciesCatalogEntry? genusSp = catalog.find(
      scientificName: 'Buteo sp.',
    );
    expect(genusSp, isNotNull);
    expect(genusSp!.scientificName, 'Buteo buteo');
  });
}
