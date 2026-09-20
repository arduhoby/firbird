import 'package:firbird/app/bird_photo.dart';
import 'package:firbird/app/detection_evidence_sheet.dart';
import 'package:firbird/audio/audio_evidence_assessment.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:firbird/detection/detection_score_aggregate.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BirdDetectionCard extends StatelessWidget {
  const BirdDetectionCard({
    required this.record,
    super.key,
    this.isHighlighted = false,
    this.isRareAlertActive = false,
    this.isRareAlertPulse = false,
    this.onSeek,
    this.onVerdict,
    this.onAudioReview,
  });

  final DetectionRecord record;
  final bool isHighlighted;
  final bool isRareAlertActive;
  final bool isRareAlertPulse;
  final VoidCallback? onSeek;
  final ValueChanged<DetectionVerdict>? onVerdict;
  final Future<void> Function(AudioReviewVerdict verdict)? onAudioReview;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int score =
        record.evidence?.finalScore ??
        DetectionScoreAggregate.combinedPercentFor(
          averageConfidence: record.modelConfidence,
          independentEventCount: record.repeatedHits,
          pointsPerAdditionalEvent: record.repetitionSupportPerHit,
        );
    final Color scoreColor = score >= 60
        ? Colors.green
        : score >= 40
        ? Colors.orange
        : theme.colorScheme.error;
    final Color categoryBorder = switch (record.statusCategory) {
      SpeciesStatusCategory.localOrMigratory => Colors.green,
      SpeciesStatusCategory.outOfRegion => Colors.grey,
      SpeciesStatusCategory.rare => theme.colorScheme.outlineVariant,
    };
    final double backgroundAlpha = theme.brightness == Brightness.dark
        ? 0.20
        : 0.11;
    final bool showRarePulse =
        record.statusCategory == SpeciesStatusCategory.rare &&
        isRareAlertActive &&
        isRareAlertPulse;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: categoryBorder,
          width: record.statusCategory == SpeciesStatusCategory.rare ? 1 : 1.8,
        ),
        boxShadow: showRarePulse
            ? <BoxShadow>[
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.78),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final DetectionVerdict? verdict = await showDetectionEvidenceSheet(
            context,
            record,
          );
          if (verdict != null) onVerdict?.call(verdict);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              BirdPhoto(
                speciesId: record.speciesId,
                scientificName: record.scientificName,
                imageUrl: record.thumbnailUrl,
                size: 54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.turkishName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      record.scientificName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: <Widget>[
                        _DetectionBadge(
                          label: DateFormat(
                            'HH:mm',
                          ).format(record.detectedAt.toLocal()),
                          color: theme.colorScheme.secondary,
                        ),
                        _DetectionBadge(
                          label: switch (record.source) {
                            DetectionSource.live => 'Canlı',
                            DetectionSource.audioFile => 'Ses dosyası',
                            DetectionSource.photo => 'Fotoğraf',
                            DetectionSource.replay => 'Replay',
                          },
                          color: theme.colorScheme.tertiary,
                        ),
                        if (record.repeatedHits > 1)
                          _DetectionBadge(
                            label: '${record.repeatedHits}× duyuldu',
                            color: Colors.green,
                          ),
                        if (record.repeatedHits > 1)
                          _DetectionBadge(
                            label:
                                'Model ort. %${(record.modelConfidence * 100).round().clamp(0, 100)}',
                            color: theme.colorScheme.secondary,
                          ),
                        if (record.statusCategory == SpeciesStatusCategory.rare)
                          _DetectionBadge(
                            label: 'Nadir Tür',
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        if (isHighlighted)
                          const _DetectionBadge(
                            label: 'Yeni / aktif',
                            color: Colors.blue,
                          ),
                        if (record.audioEvidence != null)
                          _DetectionBadge(
                            label: _audioEvidenceLabel(record.audioEvidence!),
                            color: _audioEvidenceColor(
                              record.audioEvidence!,
                              theme,
                            ),
                          ),
                        if (record.audioReviewVerdict != null)
                          _DetectionBadge(
                            label: _audioReviewLabel(
                              record.audioReviewVerdict!,
                            ),
                            color: _audioReviewColor(
                              record.audioReviewVerdict!,
                              theme,
                            ),
                          ),
                      ],
                    ),
                    if (onAudioReview != null) ...<Widget>[
                      const SizedBox(height: 10),
                      AudioEvidenceReviewControls(
                        selected: record.audioReviewVerdict,
                        onChanged: onAudioReview!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '%$score',
                      style: TextStyle(
                        color: scoreColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (onSeek != null)
                    IconButton(
                      tooltip: 'Tespit anını dinle',
                      onPressed: onSeek,
                      icon: const Icon(Icons.play_circle_outline),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.chevron_right, size: 20),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AudioEvidenceReviewControls extends StatelessWidget {
  const AudioEvidenceReviewControls({
    required this.selected,
    required this.onChanged,
    this.expanded = false,
    super.key,
  });

  final AudioReviewVerdict? selected;
  final Future<void> Function(AudioReviewVerdict verdict) onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final List<Widget> controls = AudioReviewVerdict.values
        .map(
          (AudioReviewVerdict verdict) => ChoiceChip(
            label: SizedBox(
              width: expanded ? double.infinity : null,
              child: Text(
                _audioReviewActionLabel(verdict),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ),
            selected: selected == verdict,
            padding: expanded
                ? const EdgeInsets.symmetric(horizontal: 6, vertical: 12)
                : null,
            onSelected: (_) => onChanged(verdict),
          ),
        )
        .toList(growable: false);
    if (!expanded) {
      return Wrap(spacing: 6, runSpacing: 6, children: controls);
    }
    return Row(
      children: <Widget>[
        for (int index = 0; index < controls.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: controls[index]),
        ],
      ],
    );
  }
}

String _audioEvidenceLabel(AudioEvidenceAssessment assessment) =>
    switch (assessment.level) {
      AudioEvidenceLevel.strong => 'Ses güçlü · doğrula',
      AudioEvidenceLevel.review => 'Ses zayıf · incele',
      AudioEvidenceLevel.machineOnly => 'Yalnız makine sinyali',
    };

Color _audioEvidenceColor(
  AudioEvidenceAssessment assessment,
  ThemeData theme,
) => switch (assessment.level) {
  AudioEvidenceLevel.strong => Colors.green,
  AudioEvidenceLevel.review => Colors.orange,
  AudioEvidenceLevel.machineOnly => theme.colorScheme.outline,
};

String _audioReviewLabel(AudioReviewVerdict verdict) => switch (verdict) {
  AudioReviewVerdict.audible => 'İnsan doğruladı: duyuluyor',
  AudioReviewVerdict.uncertain => 'İnsan değerlendirmesi: belirsiz',
  AudioReviewVerdict.inaudible => 'İnsan doğruladı: anlaşılmıyor',
};

String _audioReviewActionLabel(AudioReviewVerdict verdict) => switch (verdict) {
  AudioReviewVerdict.audible => 'Duyuluyor',
  AudioReviewVerdict.uncertain => 'Emin değilim',
  AudioReviewVerdict.inaudible => 'Anlaşılmıyor',
};

Color _audioReviewColor(AudioReviewVerdict verdict, ThemeData theme) =>
    switch (verdict) {
      AudioReviewVerdict.audible => Colors.green,
      AudioReviewVerdict.uncertain => Colors.orange,
      AudioReviewVerdict.inaudible => theme.colorScheme.error,
    };

class _DetectionBadge extends StatelessWidget {
  const _DetectionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );
}
