import 'package:firbird/species/species_catalog.dart';
import 'package:flutter/material.dart';

class BirdPhoto extends StatelessWidget {
  const BirdPhoto({
    super.key,
    this.speciesId,
    this.scientificName,
    this.imageUrl,
    this.size = 54,
    this.borderRadius = 10,
  });

  final String? speciesId;
  final String? scientificName;
  final String? imageUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SpeciesCatalogRepository.instance.imageUrlFor(
        speciesId: speciesId,
        scientificName: scientificName,
        preferredUrl: imageUrl,
      ),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final String? resolvedUrl = snapshot.data;
        if (resolvedUrl == null || resolvedUrl.isEmpty) {
          return _PhotoUnavailable(size: size, borderRadius: borderRadius);
        }
        return Semantics(
          image: true,
          label: '${scientificName ?? speciesId ?? 'Kuş'} fotoğrafı',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.network(
              resolvedUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              errorBuilder: (_, _, _) =>
                  _PhotoUnavailable(size: size, borderRadius: borderRadius),
              loadingBuilder:
                  (BuildContext context, Widget child, ImageChunkEvent? event) {
                    if (event == null) return child;
                    return SizedBox.square(
                      dimension: size,
                      child: const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
            ),
          ),
        );
      },
    );
  }
}

class _PhotoUnavailable extends StatelessWidget {
  const _PhotoUnavailable({required this.size, required this.borderRadius});

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(borderRadius),
    ),
    child: const Text(
      'Fotoğraf\nyok',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
    ),
  );
}
