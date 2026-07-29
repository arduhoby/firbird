import 'package:firbird/inference/birdnet_label_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects only exact BirdNET non-bird classes', () {
    expect(isBirdNetNonBirdClass('Dog'), isTrue);
    expect(isBirdNetNonBirdClass('Human vocal'), isTrue);
    expect(isBirdNetNonBirdClass('Power tools'), isTrue);
    expect(isBirdNetNonBirdClass('Environmental'), isTrue);
  });

  test('does not reject bird names containing car or cat', () {
    const List<String> affectedBirds = <String>[
      'Bubulcus ibis',
      'Calcarius lapponicus',
      'Carduelis carduelis',
      'Carpodacus erythrinus',
      'Carpospiza brachydactyla',
      'Ficedula albicollis',
      'Ficedula hypoleuca',
      'Ficedula parva',
      'Ficedula semitorquata',
      'Haematopus ostralegus',
      'Merops nubicoides',
      'Microcarbo pygmeus',
      'Muscicapa striata',
      'Nucifraga caryocatactes',
      'Phalacrocorax carbo',
      'Phalaropus fulicarius',
      'Phylloscopus fuscatus',
      'Pluvialis apricaria',
      'Prinia lepida',
    ];

    for (final String scientificName in affectedBirds) {
      expect(
        isBirdNetNonBirdClass(scientificName),
        isFalse,
        reason: '$scientificName must remain a valid bird candidate',
      );
    }
  });
}
