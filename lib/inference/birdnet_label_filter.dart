/// BirdNET labels that represent background or non-bird classes rather than
/// biological bird taxa. Matching is deliberately exact: substring matching
/// would incorrectly reject taxa such as Carduelis ("car") and flycatchers
/// ("cat").
const Set<String> birdNetNonBirdScientificNames = <String>{
  'canis lupus',
  'dog',
  'engine',
  'environmental',
  'fireworks',
  'gun',
  'human non-vocal',
  'human vocal',
  'human whistle',
  'noise',
  'power tools',
  'siren',
};

bool isBirdNetNonBirdClass(String scientificName) =>
    birdNetNonBirdScientificNames.contains(
      scientificName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
    );
