import 'package:firbird/app/bird_photo.dart';
import 'package:firbird/app/detection_evidence_sheet.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BirdDetectionCard extends StatelessWidget {
  const BirdDetectionCard({
    required this.record,
    super.key,
    this.isHighlighted = false,
    this.onSeek,
  });

  final DetectionRecord record;
  final bool isHighlighted;
  final VoidCallback? onSeek;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int score =
        record.evidence?.finalScore ??
        (record.modelConfidence * 100).round().clamp(0, 100);
    final Color color = score >= 60
        ? Colors.green
        : score >= 40
        ? Colors.orange
        : theme.colorScheme.error;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.42)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? theme.colorScheme.primary : color,
          width: isHighlighted ? 2 : 1.3,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showDetectionEvidenceSheet(context, record),
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
                      ],
                    ),
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
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '%$score',
                      style: TextStyle(
                        color: color,
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
