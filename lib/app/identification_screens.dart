import 'dart:io';

import 'package:firbird/data/app_database.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/app/sex_age_correction_sheet.dart';
import 'package:firbird/inference/audio_inference_engine.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/inference/onnx_bird_inference_engine.dart';
import 'package:firbird/inference/onnx_bird_detector.dart';
import 'package:firbird/inference/bird_cropper.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

final candidateThresholdProvider = FutureProvider<double>(
  (Ref ref) => ref.read(appDatabaseProvider).candidateThreshold(),
);

class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({required this.request, super.key});

  final IdentificationRequest request;

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  BirdInferenceEngine? _engine;
  late final Future<InferenceResult> _result;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _result = _runFullInference();
  }

  Future<InferenceResult> _runFullInference() async {
    final AppDatabase database = ref.read(appDatabaseProvider);
    final String cropMode = await database.cropMode();
    
    ImageInput finalImage = widget.request.image;
    final String ext = p.extension(finalImage.uri).toLowerCase();
    final bool isAudio = ['.mp3', '.m4a', '.wav', '.aac', '.mp4'].contains(ext);
    
    if (isAudio) {
      final Directory? extDir = await getExternalStorageDirectory();
      final String modelPath = p.join(extDir!.path, 'firbird_test_model', 'birdnet.onnx');
      final String labelsPath = p.join(extDir.path, 'firbird_test_model', 'birdnet_labels.txt');
      _engine = AudioInferenceEngine(modelPath: modelPath, labelsPath: labelsPath);
    } else {
      _engine = OnnxBirdInferenceEngine.fromExternalTestFiles();
    }
    
    if (cropMode == 'auto' && !isAudio) {
      try {
        final File modelFile = await OnnxBirdDetector.ensureModelExtracted();
        final OnnxBirdDetector detector = OnnxBirdDetector(modelFile: modelFile);
        final List<BirdBoundingBox> boxes = await detector.detect(finalImage);
        
        if (boxes.isNotEmpty) {
          // En yüksek olasılıklı kutu (zaten sıralı geliyor)
          final BirdBoundingBox bestBox = boxes.first;
          
          final String? croppedPath = await BirdCropper.cropBird(
            finalImage.uri, 
            bestBox,
          );
          
          if (croppedPath != null) {
            finalImage = ImageInput(uri: croppedPath);
          }
        }
      } catch (e) {
        // Hata olursa orijinal resimle devam et
        debugPrint('Crop failed: $e');
      }
    }

    return _engine!.identify(finalImage, widget.request.context);
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analyzing),
        leading: const BackToHomeButton(),
      ),
      body: FutureBuilder<InferenceResult>(
        future: _result,
        builder:
            (BuildContext context, AsyncSnapshot<InferenceResult> snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text(l10n.inferenceFailed));
              }
              if (snapshot.hasData && !_hasNavigated) {
                _hasNavigated = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  InferenceResult result = snapshot.data!;
                  final int? recordId = await _saveToHistory(result);
                  if (recordId != null) {
                    result = result.copyWith(recordId: recordId);
                  }
                  if (mounted) {
                    context.pushReplacement('/result', extra: result);
                  }
                });
              }

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 32),
                    _AnalysisStep(label: l10n.preparingImage),
                    _AnalysisStep(label: l10n.findingBird),
                    _AnalysisStep(label: l10n.comparingSpecies),
                    _AnalysisStep(label: l10n.calculatingRegionalResults),
                  ],
                ),
              );
            },
      ),
    );
  }

  Future<int?> _saveToHistory(InferenceResult result) async {
    if (result.predictions.isEmpty) return null;
    final AppDatabase database = ref.read(appDatabaseProvider);
    if (!await database.isHistoryEnabled()) return null;
    final SpeciesPrediction first = result.predictions.first;
    final String confidence = switch (first.score) {
      >= 0.8 => 'Yüksek eşleşme',
      >= 0.5 => 'Orta eşleşme',
      _ => 'Düşük eşleşme',
    };
    return database.addIdentification(
      speciesId: first.speciesId,
      turkishName: first.turkishName,
      scientificName: first.scientificName,
      confidence: confidence,
      modelVersion: result.modelVersion,
      imageUri: result.sourceImageUri,
      sexCategory: result.sexAge?.sex.displayCategory.name,
      sexConfidence: result.sexAge?.sex.confidence,
      ageCategory: result.sexAge?.age.displayCategory.name,
      ageConfidence: result.sexAge?.age.confidence,
      predictionMethod: result.sexAge?.sex.method.name,
    );
  }
}

class _AnalysisStep extends StatelessWidget {
  const _AnalysisStep({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({required this.result, super.key});

  final InferenceResult result;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late InferenceResult _currentResult;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final SpeciesPrediction first = _currentResult.predictions.first;
    final bool hasReliableMatch = first.score >= 0.65;
    final double threshold = ref
        .watch(candidateThresholdProvider)
        .when(
          data: (double value) => value,
          loading: () => 0.20,
          error: (_, _) => 0.20,
        );
    final List<SpeciesPrediction> visiblePredictions = _currentResult.predictions
        .where((SpeciesPrediction prediction) => prediction.score >= threshold)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.identificationResult),
        leading: const BackToHomeButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          if (!hasReliableMatch) ...<Widget>[
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Guvenilir eslesme bulunamadi. Bu fotograf icin modelin tur listesi yetersiz olabilir; dusuk skorlu adaylari kesin sonuc olarak kullanmayin.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            color: const Color(0xFFE1F2FF),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _ConfidenceChip(score: first.score),
                  const SizedBox(height: 12),
                  if (_sourceImageExists(_currentResult.sourceImageUri))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(_currentResult.sourceImageUri!),
                        width: double.infinity,
                        height: 235,
                        fit: BoxFit.cover,
                        semanticLabel: 'Tanımlanan kuş fotoğrafı',
                      ),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    <String>[
                      first.turkishName,
                      first.scientificName,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (first.originLabel != null) ...<Widget>[
                    const SizedBox(height: 8),
                    _OriginBadge(label: first.originLabel!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // --- Cinsiyet & Yaşam Evresi bölümü ---
          if (_currentResult.sexAge != null)
            _SexAgeSection(
              recordId: _currentResult.recordId,
              sexAge: _currentResult.sexAge!,
              onSpeciesCorrected: (SpeciesPrediction newSpecies) {
                setState(() {
                  final List<SpeciesPrediction> newPredictions = List<SpeciesPrediction>.from(_currentResult.predictions);
                  // Remove if exists and place at the beginning
                  newPredictions.removeWhere((SpeciesPrediction p) => p.speciesId == newSpecies.speciesId);
                  newPredictions.insert(0, newSpecies);
                  _currentResult = _currentResult.copyWith(
                    predictions: newPredictions,
                  );
                });
              },
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final SexAgeCorrectionResult? res = await showSexAgeCorrectionSheet(
                    context,
                    recordId: _currentResult.recordId,
                  );
                  if (res != null && res.species != null) {
                    setState(() {
                      final List<SpeciesPrediction> newPredictions = List<SpeciesPrediction>.from(_currentResult.predictions);
                      newPredictions.removeWhere((SpeciesPrediction p) => p.speciesId == res.species!.speciesId);
                      newPredictions.insert(0, res.species!);
                      _currentResult = _currentResult.copyWith(
                        predictions: newPredictions,
                      );
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tür düzeltmesi kaydedildi')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Sonucu Değerlendir / Düzelt'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.topCandidates,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (visiblePredictions.isNotEmpty)
            _CandidateTable(predictions: visiblePredictions)
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Seçili eşik üzerinde ek aday bulunamadı.'),
            ),
          const SizedBox(height: 16),
          if (!_currentResult.locationAffectedResult)
            _ContextEffect(label: l10n.locationEffect),
          if (!_currentResult.dateAffectedResult)
            _ContextEffect(label: l10n.dateEffect),
          const SizedBox(height: 16),
          Text(
            <String>[l10n.modelVersion, _currentResult.modelVersion].join(': '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            _currentResult.modelVersion.startsWith('mock')
                ? l10n.mockResultNotice
                : 'BioCLIP-2 cihaz içi modeli kullanılıyor · Türkiye test paketi: 382 düzenli/göçmen tür ve 82 nadir kayıt. Sonuç bir öneridir; fotoğraf net değilse kesin kabul etmeyin.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _share(context, first),
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.shareResult),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/photo'),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Yeni arama'),
          ),
        ],
      ),
    );
  }

  bool _sourceImageExists(String? uri) => uri != null && File(uri).existsSync();

  Future<void> _share(BuildContext context, SpeciesPrediction first) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String text = l10n.shareText(first.turkishName, first.scientificName);
    return SharePlus.instance.share(ShareParams(text: text));
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String label = switch (score) {
      >= 0.8 => l10n.highMatch,
      >= 0.5 => l10n.mediumMatch,
      _ => l10n.lowMatch,
    };

    return Chip(label: Text('$label · %${(score * 100).round()}'));
  }
}

class _PredictionNames extends StatelessWidget {
  const _PredictionNames({required this.prediction});

  final SpeciesPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final List<String> names = <String>[
      prediction.scientificName,
      prediction.englishName,
      ...prediction.alternativeNames,
    ].where((String name) => name != prediction.turkishName).toList();
    return Text(names.join(' · '));
  }
}

class _AlternativeNames extends StatelessWidget {
  const _AlternativeNames({required this.prediction});

  final SpeciesPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final List<String> names = <String>[
      prediction.englishName,
      ...prediction.alternativeNames,
    ].where((String name) => name != prediction.turkishName).toList();
    if (names.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('Diger adlar: ${names.join(' · ')}'),
    );
  }
}

class _ContextEffect extends StatelessWidget {
  const _ContextEffect({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4C4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline, color: Color(0xFF9A4D00)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF4A2A00),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l10n.contextNotUsed,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF4A2A00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateTable extends StatelessWidget {
  const _CandidateTable({required this.predictions});

  final List<SpeciesPrediction> predictions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: predictions
            .map((SpeciesPrediction prediction) {
              final bool isLast = identical(prediction, predictions.last);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push('/species/demo', extra: prediction),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                  ),
                  child: Row(
                    children: <Widget>[
                      _CandidateThumbnail(url: prediction.thumbnailUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              <String>[
                                    prediction.turkishName,
                                    prediction.scientificName,
                                  ]
                                  .where((String name) => name.isNotEmpty)
                                  .join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            if (prediction.originLabel != null) ...<Widget>[
                              const SizedBox(height: 4),
                              _OriginBadge(label: prediction.originLabel!),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 54,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '%${(prediction.score * 100).round()}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _OriginBadge extends StatelessWidget {
  const _OriginBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFE8F5E9),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: const Color(0xFF28633A),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _CandidateThumbnail extends StatelessWidget {
  const _CandidateThumbnail({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Container(
      width: 54,
      height: 54,
      color: Theme.of(context).colorScheme.secondaryContainer,
      alignment: Alignment.center,
      child: const Icon(Icons.flutter_dash_outlined),
    );
    if (url == null || url!.isEmpty)
      return ClipRRect(borderRadius: BorderRadius.circular(8), child: fallback);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class SpeciesDetailScreen extends StatelessWidget {
  const SpeciesDetailScreen({required this.prediction, super.key});

  final SpeciesPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.speciesDetail),
        leading: const BackToHomeButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            prediction.turkishName,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(prediction.scientificName),
          const SizedBox(height: 24),
          _DetailSection(
            title: 'Model guveni',
            value: '%${(prediction.score * 100).round()}',
          ),
          _DetailSection(title: 'Ingilizce adi', value: prediction.englishName),
          if (prediction.alternativeNames.isNotEmpty)
            _DetailSection(
              title: 'Diger adlar',
              value: prediction.alternativeNames.join(' · '),
            ),
          _DetailSection(
            title: 'Nasil dogrularim?',
            value:
                'Fotografta kusun basi, gagasi, kanat deseni ve kuyrugu net mi kontrol et. Ilk bes adayi birlikte karsilastir; tek basina model skoru kesin teshis degildir.',
          ),
          _DetailSection(
            title: 'Sonucun anlami',
            value:
                'Bu, fotograf uzerinden cihazda uretilen bir adaydir. Turkiye bolge paketi tamamlandiginda dagilim ve mevsim bilgisiyle yeniden siralanacaktir.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openTrakus(context),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Trakuş’ta fotoğraflar ve bilgi'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _openOrnito(context),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Ornito.org’da tür bilgisi'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Trakuş fotoğrafları ve gözlemleri; Ornito.org ise Türkiye dağılımı ve tür bilgisini karşılaştırmak için açılır.',
          ),
        ],
      ),
    );
  }

  Future<void> _openTrakus(BuildContext context) async {
    final Uri uri = Uri.https(
      'trakus.org',
      '/tr/kuslar/${_trakusSlug(prediction.turkishName)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trakuş acilamadi.')));
    }
  }

  Future<void> _openSource(BuildContext context, String site) async {
    final Uri uri = Uri.https('www.google.com', '/search', <String, String>{
      'q': 'site:$site ${prediction.turkishName}',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bilgi kaynagi acilamadi.')));
    }
  }

  Future<void> _openOrnito(BuildContext context) async {
    if (prediction.ornitoId != null) {
      final Uri uri = Uri.https(
        'ornito.org',
        '/Bird/Detail/${prediction.ornitoId}',
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ornito.org acilamadi.')));
      }
      return;
    }
    await _openSource(context, 'ornito.org/Bird');
  }

  String _trakusSlug(String name) => name
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ğ', 'g')
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ş', 's')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-|-$)'), '');
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value),
    );
  }
}

// ---------------------------------------------------------------------------
// Cinsiyet & Yaşam Evresi bölümü
// ---------------------------------------------------------------------------

class _SexAgeSection extends ConsumerStatefulWidget {
  const _SexAgeSection({
    required this.recordId,
    required this.sexAge,
    this.onSpeciesCorrected,
  });

  final int? recordId;
  final SexAgePrediction sexAge;
  final void Function(SpeciesPrediction)? onSpeciesCorrected;

  @override
  ConsumerState<_SexAgeSection> createState() => _SexAgeSectionState();
}

class _SexAgeSectionState extends ConsumerState<_SexAgeSection> {
  late SexAgePrediction _current;

  @override
  void initState() {
    super.initState();
    _current = widget.sexAge;
  }

  Future<void> _openCorrection() async {
    final SexAgeCorrectionResult? res = await showSexAgeCorrectionSheet(
      context,
      recordId: widget.recordId,
      initialSex: _current.sex.displayCategory,
      initialAge: _current.age.displayCategory,
    );

    if (res != null) {
      if (res.species != null && widget.onSpeciesCorrected != null) {
        widget.onSpeciesCorrected!(res.species!);
      }
      setState(() {
        final PredictionMethod newMethod = res.userApproved
            ? PredictionMethod.userApproved
            : PredictionMethod.userValidated;
            
        _current = SexAgePrediction(
          sex: SexPrediction(
            scores: res.sex != null ? <SexCategory, double>{res.sex!: 1.0} : _current.sex.scores,
            method: newMethod,
          ),
          age: AgePrediction(
            scores: res.age != null ? <AgeCategory, double>{res.age!: 1.0} : _current.age.scores,
            method: newMethod,
            terminology: _current.age.terminology,
          ),
          conflictWarning: _current.conflictWarning,
          isSexUnreliable: _current.isSexUnreliable,
        );
      });
      if (mounted && res.species != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tür düzeltmesi kaydedildi')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final SexPrediction sex = _current.sex;
    final AgePrediction age = _current.age;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Başlık
          Row(
            children: <Widget>[
              Icon(Icons.biotech_outlined, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.sexAgeTitle,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Çelişki uyarısı
          if (_current.conflictWarning)
            _SexAgeWarning(
              message: l10n.sexAgeConflictWarning,
              color: const Color(0xFFFFF3CD),
              iconColor: const Color(0xFF856404),
            ),

          // Cinsiyet skoru satırı
          Text(l10n.sexLabel, style: text.labelLarge),
          const SizedBox(height: 6),
          _buildSexBars(context, sex, l10n, _current.isSexUnreliable),
          const SizedBox(height: 14),

          // Yaşam evresi skoru satırı
          Text(l10n.ageLabel, style: text.labelLarge),
          const SizedBox(height: 6),
          _buildAgeBars(context, age, l10n),
          const SizedBox(height: 14),

          // Yöntem etiketi
          Text(
            sex.method.label,
            style: text.bodySmall?.copyWith(color: colors.outline),
          ),
          const SizedBox(height: 12),

          // Düzelt butonu
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openCorrection,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(l10n.correctSexAge),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSexBars(
    BuildContext context,
    SexPrediction sex,
    AppLocalizations l10n,
    bool isUnreliable,
  ) {
    if (isUnreliable) {
      return Text(
        l10n.sexUnreliableWarning,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.error),
      );
    }

    final bool lowConfidence = sex.displayCategory == SexCategory.unknown &&
        (sex.scores[SexCategory.female] ?? 0) < 0.60 &&
        (sex.scores[SexCategory.male] ?? 0) < 0.60;

    if (lowConfidence) {
      return Text(
        l10n.sexUnknown,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    return Column(
      children: <Widget>[
        _ScoreBar(
          label: l10n.sexFemale,
          score: sex.scores[SexCategory.female] ?? 0,
          color: const Color(0xFFE91E8C),
        ),
        const SizedBox(height: 4),
        _ScoreBar(
          label: l10n.sexMale,
          score: sex.scores[SexCategory.male] ?? 0,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 4),
        _ScoreBar(
          label: l10n.sexUnknown,
          score: sex.scores[SexCategory.unknown] ?? 0,
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _buildAgeBars(
    BuildContext context,
    AgePrediction age,
    AppLocalizations l10n,
  ) {
    return Column(
      children: <Widget>[
        _ScoreBar(
          label: age.labelFor(AgeCategory.adult),
          score: age.scores[AgeCategory.adult] ?? 0,
          color: const Color(0xFF2E7D32),
        ),
        const SizedBox(height: 4),
        _ScoreBar(
          label: age.labelFor(AgeCategory.juvenile),
          score: age.scores[AgeCategory.juvenile] ?? 0,
          color: const Color(0xFF558B2F),
        ),
        const SizedBox(height: 4),
        _ScoreBar(
          label: age.labelFor(AgeCategory.chick),
          score: age.scores[AgeCategory.chick] ?? 0,
          color: const Color(0xFF9E9D24),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.score,
    required this.color,
  });

  final String label;
  final double score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final int pct = (score * 100).round();
    return Row(
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              color: color,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '%$pct',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _SexAgeWarning extends StatelessWidget {
  const _SexAgeWarning({
    required this.message,
    required this.color,
    required this.iconColor,
  });

  final String message;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: iconColor),
            ),
          ),
        ],
      ),
    );
  }
}
