import 'package:firbird/app/app_config.dart';
import 'package:firbird/app/app_drawer.dart';
import 'package:firbird/app/app_bar_help_button.dart';
import 'package:firbird/app/firbird_app.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/app/media_player_screen.dart';
import 'package:firbird/data/app_database.dart';
import 'package:firbird/detection/algorithm_settings.dart';
import 'package:firbird/detection/detection_score_aggregate.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:firbird/observation_context/ebird_live_observation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.recentIdentifications),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menü',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: const [AppBarHelpButton(), BackToHomeButton()],
      ),
      body: StreamBuilder<List<IdentificationRecord>>(
        stream: database.watchHistory(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<IdentificationRecord>> snapshot,
            ) {
              final List<IdentificationRecord> records =
                  snapshot.data ?? <IdentificationRecord>[];
              if (records.isEmpty) {
                return Center(child: Text(l10n.historyEmpty));
              }

              // Group live session records (packageId starting with 'live_')
              final List<_HistoryListItem> items = [];
              final Map<String, List<IdentificationRecord>> liveSessionGroups =
                  {};

              for (final record in records) {
                final String? packageId = record.packageId;
                final bool isLive =
                    packageId != null && packageId.startsWith('live_');

                if (isLive) {
                  liveSessionGroups
                      .putIfAbsent(packageId, () => [])
                      .add(record);
                } else {
                  items.add(_HistoryListItem.singleRecord(record));
                }
              }

              // Convert live session groups to single summary items
              for (final entry in liveSessionGroups.entries) {
                final groupRecords = entry.value;
                items.add(
                  _HistoryListItem.liveSessionGroup(
                    sessionId: entry.key,
                    records: groupRecords,
                    createdAt: groupRecords.first.createdAt,
                  ),
                );
              }

              // Sort items by creation date (newest first)
              items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) {
                  final _HistoryListItem item = items[index];

                  if (item.isSessionGroup) {
                    final groupRecords = item.groupRecords!;
                    final int count = groupRecords.length;
                    final int rareCount = groupRecords
                        .where(
                          (IdentificationRecord record) =>
                              _statusCategory(
                                record.speciesStatus,
                                record.scientificName,
                              ) ==
                              SpeciesStatusCategory.rare,
                        )
                        .length;
                    final List<String> topNames = groupRecords
                        .take(3)
                        .map((r) => r.turkishName)
                        .toList();
                    final String namesSummary =
                        topNames.join(', ') + (count > 3 ? '...' : '');

                    // Format session label
                    final String dateStr =
                        '${item.createdAt.day.toString().padLeft(2, '0')}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.year} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

                    return Dismissible(
                      key: ValueKey<String>('session_${item.sessionId}'),
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) =>
                          database.deleteLiveSession(item.sessionId!),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        elevation: 0.5,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.mic,
                              color: theme.colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(
                                'Canlı Oturum',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$count Tür',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateStr,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  namesSummary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (rareCount > 0)
                                  Text(
                                    '$rareCount nadir tür tespiti',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          onTap: () => _showLiveSessionDetails(
                            context,
                            dateStr,
                            groupRecords,
                            database,
                          ),
                        ),
                      ),
                    );
                  }

                  // Single regular record (photo / file identification)
                  final IdentificationRecord record = item.singleRecord!;
                  return Dismissible(
                    key: ValueKey<int>(record.id),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                      ),
                    ),
                    onDismissed: (_) =>
                        database.deleteIdentification(record.id),
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLowest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: theme.colorScheme.secondaryContainer,
                          child: Icon(
                            Icons.flutter_dash,
                            size: 20,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                        title: Text(
                          record.turkishName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          record.scientificName,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            record.confidence,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => database.clearHistory(),
        icon: const Icon(Icons.delete_outline),
        label: Text(l10n.clearHistory),
      ),
    );
  }

  /// Opens the full session summary table in a modal bottom sheet
  void _showLiveSessionDetails(
    BuildContext context,
    String dateStr,
    List<IdentificationRecord> records,
    AppDatabase database,
  ) {
    final theme = Theme.of(context);
    final String? audioPath = records.first.imageUri;
    final int rareCount = records
        .where(
          (IdentificationRecord record) =>
              _statusCategory(record.speciesStatus, record.scientificName) ==
              SpeciesStatusCategory.rare,
        )
        .length;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        radius: 20,
                        child: Icon(
                          Icons.mic,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Canlı Oturum Detayı',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (rareCount > 0)
                              Text(
                                '$rareCount nadir tür tespiti',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Chip(
                        avatar: const Icon(Icons.flutter_dash, size: 16),
                        label: Text('${records.length} Tür'),
                        backgroundColor: theme.colorScheme.primaryContainer,
                      ),
                    ],
                  ),

                  if (audioPath != null) ...[
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final String sessionId = records.first.packageId!;
                        final List<LiveDetectionEvent> events = await database
                            .eventsForLiveSession(sessionId);
                        final AlgorithmSettings algorithmSettings =
                            await AlgorithmSettingsRepository().load();
                        if (!context.mounted) return;
                        if (events.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bu oturumda oynatılabilir tespit olayı yok.',
                              ),
                            ),
                          );
                          return;
                        }
                        if (!context.mounted) return;
                        final int rareEventCount = events
                            .where(
                              (LiveDetectionEvent event) =>
                                  _statusCategory(
                                    event.speciesStatus,
                                    event.scientificName,
                                  ) ==
                                  SpeciesStatusCategory.rare,
                            )
                            .map(
                              (LiveDetectionEvent event) =>
                                  event.scientificName.toLowerCase(),
                            )
                            .toSet()
                            .length;
                        final Map<String, DetectionScoreAggregate> aggregates =
                            aggregateDetectionScores(
                              events.map(
                                (LiveDetectionEvent event) =>
                                    DetectionScoreSample(
                                      key: event.scientificName,
                                      confidence: event.confidence,
                                    ),
                              ),
                            );
                        context.push(
                          '/player',
                          extra: PlaybackSession(
                            filePath: audioPath,
                            displayName: path.basename(audioPath),
                            rareSpeciesCount: rareEventCount,
                            detections: events
                                .map((LiveDetectionEvent event) {
                                  final DetectionScoreAggregate aggregate =
                                      aggregates[event.scientificName
                                          .toLowerCase()]!;
                                  return PlaybackDetection(
                                    speciesId: event.speciesId,
                                    turkishName: event.turkishName,
                                    scientificName: event.scientificName,
                                    startMs: event.startMs,
                                    endMs: event.endMs,
                                    modelConfidence:
                                        aggregate.averageConfidence,
                                    repeatedHits:
                                        aggregate.independentEventCount,
                                    repetitionSupportPerHit: algorithmSettings
                                        .repeatedDetectionSupport,
                                    regionalSupport: event.regionalSupport,
                                    temporalContext: event.temporalContext,
                                    detectedAt:
                                        event.detectedAt ??
                                        records.first.createdAt.add(
                                          Duration(milliseconds: event.startMs),
                                        ),
                                    latitude: event.latitude,
                                    longitude: event.longitude,
                                    modelVersion: 'BirdNET geçmiş kaydı',
                                    statusCategory: _statusCategory(
                                      event.speciesStatus,
                                      event.scientificName,
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.audio_file_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                path.basename(audioPath),
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.play_circle_fill, size: 30),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Text(
                    'TESPİT EDİLEN TÜRLER TABLOSU',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Detailed Table
                  Expanded(
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'TÜR',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'ZAMAN ARALIĞI',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  'TAH. ORAN',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Table content
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(12),
                              ),
                            ),
                            child: ListView.separated(
                              controller: scrollController,
                              itemCount: records.length,
                              separatorBuilder: (context, _) =>
                                  const SizedBox(height: 2),
                              itemBuilder: (context, index) {
                                final record = records[index];
                                // Parse confidence format "%89 · 01:00 – 01:35"
                                String pctStr = record.confidence;
                                String timeRange = '—';
                                if (record.confidence.contains('·')) {
                                  final parts = record.confidence.split('·');
                                  pctStr = parts.first.trim();
                                  timeRange = parts.last.trim();
                                }

                                final int pct =
                                    int.tryParse(
                                      pctStr.replaceAll('%', '').trim(),
                                    ) ??
                                    0;
                                final Color pctColor = pct >= 70
                                    ? Colors.green
                                    : pct >= 40
                                    ? Colors.orange
                                    : Colors.red;

                                // Typed v0.8.6 records carry the independent
                                // event count. Keep the legacy parser only for
                                // older local rows.
                                int count = record.repeatedHits;
                                if (record.predictionMethod?.startsWith(
                                      'count:',
                                    ) ==
                                    true) {
                                  count =
                                      int.tryParse(
                                        record.predictionMethod!.replaceAll(
                                          'count:',
                                          '',
                                        ),
                                      ) ??
                                      1;
                                }

                                final SpeciesStatusCategory statusCat =
                                    _statusCategory(
                                      record.speciesStatus,
                                      record.scientificName,
                                    );
                                final Color borderColor = statusCat.borderColor;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index.isEven
                                        ? theme.colorScheme.surface
                                        : theme
                                              .colorScheme
                                              .surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1.8,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.turkishName,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            Text(
                                              record.scientificName,
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                            if (count > 1)
                                              Text(
                                                '$count× duyuldu',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          timeRange,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontFeatures: [
                                                  const FontFeature.tabularFigures(),
                                                ],
                                              ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pctColor.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '%$pct',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: pctColor,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Tablo Açıklama Notu (Küçük Fontlu)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildModalLegendNoteItem(
                                  context,
                                  Colors.green,
                                  'Yerel / Göçmen',
                                ),
                                _buildModalLegendNoteItem(
                                  context,
                                  Colors.grey,
                                  'Bölge Dışı / Zor',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Kapat'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _HistoryListItem {
  _HistoryListItem.singleRecord(this.singleRecord)
    : isSessionGroup = false,
      sessionId = null,
      groupRecords = null,
      createdAt = singleRecord!.createdAt;

  _HistoryListItem.liveSessionGroup({
    required this.sessionId,
    required List<IdentificationRecord> records,
    required this.createdAt,
  }) : isSessionGroup = true,
       singleRecord = null,
       groupRecords = records;

  final bool isSessionGroup;
  final String? sessionId;
  final IdentificationRecord? singleRecord;
  final List<IdentificationRecord>? groupRecords;
  final DateTime createdAt;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _historyEnabled = true;
  String _cropMode = 'auto';
  double _candidateThreshold = 0.05;
  double _liveMinScore = 0.0;
  int _observationRadiusKm = 20;
  bool _hasEbirdApiKey = false;
  DateTime? _eBirdApiKeyVerifiedAt;
  AlgorithmSettings _algorithmSettings = AlgorithmSettings.defaults;
  final AlgorithmSettingsRepository _algorithmSettingsRepository =
      AlgorithmSettingsRepository();
  final EbirdLiveObservationService _ebirdLiveService =
      EbirdLiveObservationService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final AppDatabase database = ref.read(appDatabaseProvider);
    final bool history = await database.isHistoryEnabled();
    final String cropMode = await database.cropMode();
    final double threshold = await database.candidateThreshold();
    final double liveMin = await database.liveDetectionMinScore();
    final int observationRadius = await database.observationContextRadiusKm();
    final bool hasEbirdApiKey = await _ebirdLiveService.hasApiKey();
    final DateTime? eBirdApiKeyVerifiedAt = await database
        .eBirdApiKeyLastVerifiedAt();
    final AlgorithmSettings algorithmSettings =
        await _algorithmSettingsRepository.load();
    if (mounted) {
      setState(() {
        _historyEnabled = history;
        _cropMode = cropMode;
        _candidateThreshold = threshold;
        _liveMinScore = liveMin;
        _observationRadiusKm = observationRadius;
        _hasEbirdApiKey = hasEbirdApiKey;
        _eBirdApiKeyVerifiedAt = eBirdApiKeyVerifiedAt;
        _algorithmSettings = algorithmSettings;
      });
    }
  }

  Future<void> _saveAlgorithmSettings(AlgorithmSettings value) async {
    setState(() => _algorithmSettings = value);
    await _algorithmSettingsRepository.save(value);
  }

  Future<void> _editEbirdApiKey() async {
    final TextEditingController controller = TextEditingController();
    bool testing = false;
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('eBird API anahtarı'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: controller,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Kişisel API anahtarı',
                      helperText:
                          'Anahtar yalnızca bu cihazın güvenli deposunda saklanır.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://ebird.org/api/keygen'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('eBird’den kişisel API anahtarı al'),
                  ),
                  if (testing) ...<Widget>[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 6),
                    const Text('Anahtar eBird ile doğrulanıyor…'),
                  ],
                ],
              ),
              actions: <Widget>[
                if (_hasEbirdApiKey)
                  TextButton(
                    onPressed: () async {
                      await _ebirdLiveService.clearApiKey();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext, false);
                      }
                    },
                    child: const Text('Anahtarı sil'),
                  ),
                TextButton(
                  onPressed: testing
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: testing
                      ? null
                      : () async {
                          setDialogState(() => testing = true);
                          try {
                            await _ebirdLiveService.testApiKey(controller.text);
                            await _ebirdLiveService.saveApiKey(controller.text);
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } on FormatException catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(error.message)),
                              );
                            }
                          } on EbirdLiveDataException catch (error) {
                            if (dialogContext.mounted) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                SnackBar(content: Text(error.message)),
                              );
                            }
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => testing = false);
                            }
                          }
                        },
                  child: const Text('Test et ve kaydet'),
                ),
              ],
            ),
      ),
    );
    controller.dispose();
    if (saved == true) {
      final DateTime now = DateTime.now();
      await ref.read(appDatabaseProvider).setEBirdApiKeyLastVerifiedAt(now);
      if (mounted) {
        setState(() {
          _hasEbirdApiKey = true;
          _eBirdApiKeyVerifiedAt = now;
        });
      }
    } else if (saved == false) {
      await ref.read(appDatabaseProvider).clearEBirdApiKeyLastVerifiedAt();
      if (mounted) {
        setState(() {
          _hasEbirdApiKey = false;
          _eBirdApiKeyVerifiedAt = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeMode selectedTheme = ref.watch(themeSelectionProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menü',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: const [AppBarHelpButton(), BackToHomeButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: <Widget>[
          _SettingsSection(
            title: 'Genel',
            icon: Icons.tune,
            children: <Widget>[
              SwitchListTile(
                title: Text(l10n.historySetting),
                subtitle: Text(l10n.historySettingDescription),
                value: _historyEnabled,
                onChanged: (bool enabled) async {
                  await ref
                      .read(appDatabaseProvider)
                      .setHistoryEnabled(enabled);
                  if (mounted) setState(() => _historyEnabled = enabled);
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(_cropMode),
                  initialValue: _cropMode,
                  decoration: const InputDecoration(
                    labelText: 'Kırpma modu',
                    helperText: 'Kuşu fotoğrafta bulup kırpma yöntemi',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'off', child: Text('Kapalı')),
                    DropdownMenuItem(
                      value: 'manual',
                      child: Text('Manuel — önce sor'),
                    ),
                    DropdownMenuItem(value: 'auto', child: Text('Otomatik')),
                  ],
                  onChanged: (String? mode) async {
                    if (mode == null) return;
                    await ref.read(appDatabaseProvider).setCropMode(mode);
                    if (mounted) setState(() => _cropMode = mode);
                  },
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Tespit eşikleri',
            icon: Icons.auto_graph,
            children: <Widget>[
              ListTile(
                title: const Text('Aday gösterme eşiği'),
                subtitle: Text(
                  '%${(_candidateThreshold * 100).round()} altındaki öneriler gizlenir',
                ),
              ),
              Slider(
                value: _candidateThreshold,
                min: 0.05,
                max: 0.80,
                divisions: 15,
                label: '%${(_candidateThreshold * 100).round()}',
                onChanged: (double value) =>
                    setState(() => _candidateThreshold = value),
                onChangeEnd: (double value) =>
                    ref.read(appDatabaseProvider).setCandidateThreshold(value),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Canlı tespit güven eşiği'),
                subtitle: Text(
                  _liveMinScore == 0
                      ? 'Tüm tespitler gösterilir'
                      : '%${(_liveMinScore * 100).round()} altındaki tespitler gizlenir',
                ),
              ),
              Slider(
                value: _liveMinScore,
                min: 0,
                max: 0.90,
                divisions: 18,
                label: _liveMinScore == 0
                    ? 'Hepsi'
                    : '%${(_liveMinScore * 100).round()}',
                onChanged: (double value) =>
                    setState(() => _liveMinScore = value),
                onChangeEnd: (double value) => ref
                    .read(appDatabaseProvider)
                    .setLiveDetectionMinScore(value),
              ),
            ],
          ),
          _SettingsSection(
            title: 'eBird ve gözlem alanı',
            icon: Icons.radar_outlined,
            children: <Widget>[
              ListTile(
                leading: Icon(
                  _hasEbirdApiKey ? Icons.verified_rounded : Icons.key_outlined,
                  color: _hasEbirdApiKey ? Colors.green : null,
                ),
                title: const Text('eBird API anahtarı'),
                subtitle: Text(
                  _hasEbirdApiKey
                      ? 'Doğrulandı · ${_eBirdApiKeyVerifiedAt == null ? 'şimdi' : '${_eBirdApiKeyVerifiedAt!.day.toString().padLeft(2, '0')}.${_eBirdApiKeyVerifiedAt!.month.toString().padLeft(2, '0')}.${_eBirdApiKeyVerifiedAt!.year}'}\nDüzenlemek için dokunun.'
                      : 'Güncel hotspot verisi için kişisel anahtar ekleyin.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _editEbirdApiKey,
              ),
              const Divider(height: 1),
              const ListTile(
                title: Text('Gözlem yarıçapı'),
                subtitle: Text('Canlı tespit ve hotspot arama alanı'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: SegmentedButton<int>(
                  segments: const <ButtonSegment<int>>[
                    ButtonSegment<int>(value: 20, label: Text('20 km')),
                    ButtonSegment<int>(value: 50, label: Text('50 km')),
                  ],
                  selected: <int>{_observationRadiusKm},
                  onSelectionChanged: (Set<int> selection) async {
                    final int radius = selection.first;
                    await ref
                        .read(appDatabaseProvider)
                        .setObservationContextRadiusKm(radius);
                    if (mounted) {
                      setState(() => _observationRadiusKm = radius);
                    }
                  },
                ),
              ),
              ListTile(
                title: Text(l10n.activePackage),
                subtitle: const Text('Türkiye 0.1.0 · uygulamaya dahil'),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Algoritma puanları',
            icon: Icons.rule_folder_outlined,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Text(
                  'Kanıtların model puanına eklediği veya çıkardığı değerler. Değişiklikler yeni açılan kanıt dosyalarında uygulanır.',
                ),
              ),
              _AlgorithmSlider(
                title: 'Saat uyumsuzluğu cezası',
                value: _algorithmSettings.timeMismatchPenalty,
                max: 50,
                prefix: '−',
                onChanged: (int value) => setState(
                  () => _algorithmSettings = _algorithmSettings.copyWith(
                    timeMismatchPenalty: value,
                  ),
                ),
                onChangeEnd: (int value) => _saveAlgorithmSettings(
                  _algorithmSettings.copyWith(timeMismatchPenalty: value),
                ),
              ),
              _AlgorithmSlider(
                title: 'Yakında aynı saat desteği',
                value: _algorithmSettings.nearbySameTimeSupport,
                max: 50,
                prefix: '+',
                onChanged: (int value) => setState(
                  () => _algorithmSettings = _algorithmSettings.copyWith(
                    nearbySameTimeSupport: value,
                  ),
                ),
                onChangeEnd: (int value) => _saveAlgorithmSettings(
                  _algorithmSettings.copyWith(nearbySameTimeSupport: value),
                ),
              ),
              _AlgorithmSlider(
                title: 'Mevsim uyumu desteği',
                value: _algorithmSettings.seasonSupport,
                max: 25,
                prefix: '+',
                onChanged: (int value) => setState(
                  () => _algorithmSettings = _algorithmSettings.copyWith(
                    seasonSupport: value,
                  ),
                ),
                onChangeEnd: (int value) => _saveAlgorithmSettings(
                  _algorithmSettings.copyWith(seasonSupport: value),
                ),
              ),
              _AlgorithmSlider(
                title: 'Her ek bağımsız ses tespiti desteği',
                value: _algorithmSettings.repeatedDetectionSupport,
                max: 10,
                prefix: '+',
                onChanged: (int value) => setState(
                  () => _algorithmSettings = _algorithmSettings.copyWith(
                    repeatedDetectionSupport: value,
                  ),
                ),
                onChangeEnd: (int value) => _saveAlgorithmSettings(
                  _algorithmSettings.copyWith(repeatedDetectionSupport: value),
                ),
              ),
              _AlgorithmSlider(
                title: 'Cihazda doğrulanmış tür desteği',
                value: _algorithmSettings.deviceConfirmedSupport,
                max: 30,
                prefix: '+',
                onChanged: (int value) => setState(
                  () => _algorithmSettings = _algorithmSettings.copyWith(
                    deviceConfirmedSupport: value,
                  ),
                ),
                onChangeEnd: (int value) => _saveAlgorithmSettings(
                  _algorithmSettings.copyWith(deviceConfirmedSupport: value),
                ),
              ),
              _AlgorithmSlider(
                title: 'Cihazda reddedilmiş tür cezası',
                value: _algorithmSettings.deviceRejectedPenalty,
                max: 50,
                prefix: '−',
                onChanged: (int value) => setState(
                  () => _algorithmSettings = _algorithmSettings.copyWith(
                    deviceRejectedPenalty: value,
                  ),
                ),
                onChangeEnd: (int value) => _saveAlgorithmSettings(
                  _algorithmSettings.copyWith(deviceRejectedPenalty: value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await _algorithmSettingsRepository.reset();
                    if (mounted) {
                      setState(
                        () => _algorithmSettings = AlgorithmSettings.defaults,
                      );
                    }
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Varsayılan puanlara dön'),
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Görünüm',
            icon: Icons.palette_outlined,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: DropdownButtonFormField<ThemeMode>(
                  key: ValueKey<ThemeMode>(selectedTheme),
                  initialValue: selectedTheme,
                  decoration: const InputDecoration(labelText: 'Tema'),
                  items: const <DropdownMenuItem<ThemeMode>>[
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Açık'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Koyu'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Cihaz ayarını kullan'),
                    ),
                  ],
                  onChanged: (ThemeMode? mode) {
                    if (mode != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(mode);
                    }
                  },
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'Uygulama',
            icon: Icons.info_outline,
            children: <Widget>[
              FutureBuilder<String>(
                future: AppConfig.appVersion,
                builder:
                    (BuildContext context, AsyncSnapshot<String> snapshot) =>
                        ListTile(
                          title: const Text('Uygulama sürümü'),
                          subtitle: Text(snapshot.data ?? 'Yükleniyor…'),
                        ),
              ),
              ListTile(
                title: Text(l10n.privacy),
                subtitle: Text(l10n.privacySummary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ColoredBox(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ...children,
        ],
      ),
    );
  }
}

class _AlgorithmSlider extends StatelessWidget {
  const _AlgorithmSlider({
    required this.title,
    required this.value,
    required this.max,
    required this.prefix,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String title;
  final int value;
  final int max;
  final String prefix;
  final ValueChanged<int> onChanged;
  final ValueChanged<int> onChangeEnd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '$prefix$value',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: max.toDouble(),
          divisions: max,
          label: '$prefix$value',
          onChanged: (double next) => onChanged(next.round()),
          onChangeEnd: (double next) => onChangeEnd(next.round()),
        ),
      ],
    ),
  );
}

Widget _buildModalLegendNoteItem(
  BuildContext context,
  Color color,
  String label,
) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

SpeciesStatusCategory _statusCategory(
  String? storedValue,
  String scientificName,
) {
  for (final SpeciesStatusCategory value in SpeciesStatusCategory.values) {
    if (value.name == storedValue) return value;
  }
  return SpeciesStatusHelper.getCategory(scientificName: scientificName);
}
