import 'package:firbird/inference/model_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts the scientific name from a BirdNET label', () {
    expect(birdNetScientificName('Anser_anser_Greylag_Goose'), 'Anser anser');
    expect(birdNetScientificName('Anser anser_Greylag Goose'), 'Anser anser');
  });

  test('reports shared coverage using normalised scientific names', () {
    final ModelCoverageSummary coverage =
        ModelCoverageSummary.fromScientificNames(
          imageSpecies: <String>['Anser anser', 'Larus ridibundus'],
          audioSpecies: <String>['anser anser', 'Turdus merula'],
        );

    expect(coverage.imageSpeciesCount, 2);
    expect(coverage.audioSpeciesCount, 2);
    expect(coverage.sharedSpeciesCount, 1);
    expect(coverage.imageOnlySpeciesCount, 1);
    expect(coverage.audioOnlySpeciesCount, 1);
  });
}
