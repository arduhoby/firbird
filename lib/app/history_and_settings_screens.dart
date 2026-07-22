import 'dart:io';

import 'package:firbird/app/app_drawer.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/data/app_database.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

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
        actions: const [
          BackToHomeButton(),
        ],
      ),
      body: StreamBuilder<List<IdentificationRecord>>(
        stream: database.watchHistory(),
        builder: (
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
          final Map<String, List<IdentificationRecord>> liveSessionGroups = {};

          for (final record in records) {
            final String? packageId = record.packageId;
            final bool isLive = packageId != null && packageId.startsWith('live_');

            if (isLive) {
              liveSessionGroups.putIfAbsent(packageId, () => []).add(record);
            } else {
              items.add(_HistoryListItem.singleRecord(record));
            }
          }

          // Convert live session groups to single summary items
          for (final entry in liveSessionGroups.entries) {
            final groupRecords = entry.value;
            items.add(_HistoryListItem.liveSessionGroup(
              sessionId: entry.key,
              records: groupRecords,
              createdAt: groupRecords.first.createdAt,
            ));
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
                final List<String> topNames = groupRecords
                    .take(3)
                    .map((r) => r.turkishName)
                    .toList();
                final String namesSummary = topNames.join(', ') + (count > 3 ? '...' : '');

                // Format session label
                final String dateStr =
                    '${item.createdAt.day.toString().padLeft(2, '0')}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.year} ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

                return Dismissible(
                  key: ValueKey<String>('session_${item.sessionId}'),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => database.deleteLiveSession(item.sessionId!),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    elevation: 0.5,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.12),
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
                          ],
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => _showLiveSessionDetails(context, dateStr, groupRecords),
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
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => database.deleteIdentification(record.id),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                      style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
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
  ) {
    final theme = Theme.of(context);
    final String? audioPath = records.first.imageUri;

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
                        child: Icon(Icons.mic, color: theme.colorScheme.primary, size: 22),
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

                  if (audioPath != null && File(audioPath).existsSync()) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                        ],
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
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                              border: Border.all(color: theme.colorScheme.outlineVariant),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                            ),
                            child: ListView.separated(
                              controller: scrollController,
                              itemCount: records.length,
                              separatorBuilder: (context, _) => Divider(
                                height: 1,
                                color: theme.colorScheme.outlineVariant,
                              ),
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

                                final int pct = int.tryParse(pctStr.replaceAll('%', '').trim()) ?? 0;
                                final Color pctColor = pct >= 70
                                    ? Colors.green
                                    : pct >= 40
                                        ? Colors.orange
                                        : Colors.red;

                                // Parse count from predictionMethod if available e.g. "count:3"
                                int count = 1;
                                if (record.predictionMethod?.startsWith('count:') == true) {
                                  count = int.tryParse(record.predictionMethod!.replaceAll('count:', '')) ?? 1;
                                }

                                return Container(
                                  color: index.isEven
                                      ? theme.colorScheme.surface
                                      : theme.colorScheme.surfaceContainerLowest,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.turkishName,
                                              style: theme.textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              record.scientificName,
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
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
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontFeatures: [const FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: pctColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
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
  })  : isSessionGroup = true,
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
    if (mounted) {
      setState(() {
        _historyEnabled = history;
        _cropMode = cropMode;
        _candidateThreshold = threshold;
        _liveMinScore = liveMin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

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
        actions: const [
          BackToHomeButton(),
        ],
      ),
      body: ListView(
        children: <Widget>[
          SwitchListTile(
            title: Text(l10n.historySetting),
            subtitle: Text(l10n.historySettingDescription),
            value: _historyEnabled,
            onChanged: (bool enabled) async {
              await ref.read(appDatabaseProvider).setHistoryEnabled(enabled);
              if (mounted) {
                setState(() => _historyEnabled = enabled);
              }
            },
          ),
          const ListTile(
            title: Text('Kırpma Modu (Yapay Zeka)'),
            subtitle: Text('Kuşu fotoğrafta bulup kırpma yöntemi.'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                  value: 'off',
                  label: Text('Kapalı'),
                ),
                ButtonSegment<String>(
                  value: 'manual',
                  label: Text('Manuel (Sor)'),
                ),
                ButtonSegment<String>(
                  value: 'auto',
                  label: Text('Otomatik'),
                ),
              ],
              selected: <String>{_cropMode},
              onSelectionChanged: (Set<String> newSelection) async {
                final String mode = newSelection.first;
                await ref.read(appDatabaseProvider).setCropMode(mode);
                if (mounted) {
                  setState(() => _cropMode = mode);
                }
              },
            ),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Canlı Tespit — Minimum Güven Eşiği'),
            subtitle: Text(
              _liveMinScore == 0.0
                  ? 'Tüm tespitler gösterilir (filtre yok)'
                  : '%${(_liveMinScore * 100).round()} altındaki tespitler tabloya alınmaz',
            ),
          ),
          Slider(
            value: _liveMinScore,
            min: 0.0,
            max: 0.90,
            divisions: 18,
            label: _liveMinScore == 0.0
                ? 'Hepsi'
                : '%${(_liveMinScore * 100).round()}',
            onChanged: (double value) =>
                setState(() => _liveMinScore = value),
            onChangeEnd: (double value) =>
                ref.read(appDatabaseProvider).setLiveDetectionMinScore(value),
          ),
          ListTile(
            title: Text(l10n.activePackage),
            subtitle: const Text('Türkiye 0.1.0 · uygulamaya dahil'),
          ),
          const ListTile(
            title: Text('Uygulama sürümü'),
            subtitle: Text('0.3.0'),
          ),
          ListTile(
            title: Text(l10n.privacy),
            subtitle: Text(l10n.privacySummary),
          ),
        ],
      ),
    );
  }
}
