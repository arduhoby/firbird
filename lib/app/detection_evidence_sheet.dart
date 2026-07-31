import 'package:firbird/app/bird_photo.dart';
import 'package:firbird/detection/detection_evidence_service.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<DetectionVerdict?> showDetectionEvidenceSheet(
  BuildContext context,
  DetectionRecord record,
) => showModalBottomSheet<DetectionVerdict>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (BuildContext context) => FractionallySizedBox(
    heightFactor: 0.9,
    child: _DetectionEvidenceView(record: record),
  ),
);

class _DetectionEvidenceView extends StatefulWidget {
  const _DetectionEvidenceView({required this.record});

  final DetectionRecord record;

  @override
  State<_DetectionEvidenceView> createState() => _DetectionEvidenceViewState();
}

class _DetectionEvidenceViewState extends State<_DetectionEvidenceView> {
  final DetectionEvidenceService _service = DetectionEvidenceService();
  late Future<DetectionRecord> _record = _service.enrich(widget.record);
  bool _saving = false;

  Future<void> _setVerdict(
    DetectionRecord record,
    DetectionVerdict verdict,
  ) async {
    setState(() => _saving = true);
    final DetectionRecord updated = await _service.recordVerdict(
      record,
      verdict,
    );
    if (!mounted) return;
    _record = Future<DetectionRecord>.value(updated);
    Navigator.of(context).pop(verdict);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DetectionRecord>(
    future: _record,
    builder: (BuildContext context, AsyncSnapshot<DetectionRecord> snapshot) {
      if (!snapshot.hasData) {
        if (snapshot.hasError) {
          return const Center(child: Text('Kanıt dosyası hazırlanamadı.'));
        }
        return const Center(child: CircularProgressIndicator());
      }
      final DetectionRecord record = snapshot.data!;
      final DetectionEvidenceBundle bundle = record.evidence!;
      final ThemeData theme = Theme.of(context);
      final Color scoreColor = bundle.finalScore >= 60
          ? Colors.green
          : bundle.finalScore >= 40
          ? Colors.orange
          : theme.colorScheme.error;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: <Widget>[
          Row(
            children: <Widget>[
              BirdPhoto(
                speciesId: record.speciesId,
                scientificName: record.scientificName,
                imageUrl: record.thumbnailUrl,
                size: 68,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.turkishName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      record.scientificName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      DateFormat(
                        'd MMMM yyyy HH:mm',
                        'tr_TR',
                      ).format(record.detectedAt.toLocal()),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scoreColor),
                ),
                child: Text(
                  '%${bundle.finalScore}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scoreColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scoreColor.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  bundle.confidenceLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Model ort. %${bundle.modelScore} · kanıt ${bundle.contextAdjustment >= 0 ? '+' : ''}${bundle.contextAdjustment} · sonuç %${bundle.finalScore}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Neden güvenilir veya şüpheli?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...bundle.factors.map(
            (DetectionEvidenceFactor factor) =>
                _EvidenceFactorCard(factor: factor),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'eBird kayıtları yakın çevredeki varlığı destekleyebilir; kuşun tam o anda ses çıkardığını kanıtlamaz. Eksik kayıt da türün bölgede bulunmadığı anlamına gelmez. Algoritma: ${bundle.algorithmVersion}.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sizin değerlendirmeniz',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _setVerdict(record, DetectionVerdict.incorrect),
                  icon: const Icon(Icons.close),
                  label: const Text('Doğru değil'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => _setVerdict(record, DetectionVerdict.correct),
                  icon: const Icon(Icons.check),
                  label: const Text('Doğru'),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _EvidenceFactorCard extends StatelessWidget {
  const _EvidenceFactorCard({required this.factor});

  final DetectionEvidenceFactor factor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = switch (factor.direction) {
      EvidenceDirection.supports => Colors.green,
      EvidenceDirection.weakens => theme.colorScheme.error,
      EvidenceDirection.neutral => Colors.blueGrey,
      EvidenceDirection.unavailable => Colors.grey,
    };
    final IconData icon = switch (factor.direction) {
      EvidenceDirection.supports => Icons.add_circle_outline,
      EvidenceDirection.weakens => Icons.remove_circle_outline,
      EvidenceDirection.neutral => Icons.info_outline,
      EvidenceDirection.unavailable => Icons.help_outline,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          factor.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        factor.points == 0
                            ? '0'
                            : '${factor.points > 0 ? '+' : ''}${factor.points}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(factor.detail),
                  const SizedBox(height: 4),
                  Text(
                    'Kaynak: ${factor.sourceLabel}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
