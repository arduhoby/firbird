/// Shared taxonomy helpers for reconciling image and audio model coverage.
///
/// A BirdNET label starts with a scientific name followed by an underscore and
/// its common name. Both `Anser anser_Greylag Goose` and the fully underscored
/// `Anser_anser_Greylag_Goose` form are accepted.
String birdNetScientificName(String label) {
  final List<String> parts = label.trim().split('_');
  if (parts.length == 1) return parts.single;
  if (parts.first.contains(' ')) return parts.first.trim();
  if (parts.length >= 2 && RegExp(r'^[a-z]').hasMatch(parts[1])) {
    return '${parts[0]} ${parts[1]}'.trim();
  }
  return parts.first.trim();
}

class ModelCoverageSummary {
  const ModelCoverageSummary({
    required this.imageSpeciesCount,
    required this.audioSpeciesCount,
    required this.sharedSpeciesCount,
  });

  factory ModelCoverageSummary.fromScientificNames({
    required Iterable<String> imageSpecies,
    required Iterable<String> audioSpecies,
  }) {
    final Set<String> image = imageSpecies
        .map(_normaliseScientificName)
        .where((String name) => name.isNotEmpty)
        .toSet();
    final Set<String> audio = audioSpecies
        .map(_normaliseScientificName)
        .where((String name) => name.isNotEmpty)
        .toSet();
    return ModelCoverageSummary(
      imageSpeciesCount: image.length,
      audioSpeciesCount: audio.length,
      sharedSpeciesCount: image.intersection(audio).length,
    );
  }

  final int imageSpeciesCount;
  final int audioSpeciesCount;
  final int sharedSpeciesCount;
  int get imageOnlySpeciesCount => imageSpeciesCount - sharedSpeciesCount;
  int get audioOnlySpeciesCount => audioSpeciesCount - sharedSpeciesCount;
}

String _normaliseScientificName(String name) => name.trim().toLowerCase();
