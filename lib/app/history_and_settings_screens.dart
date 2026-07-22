import 'package:firbird/data/app_database.dart';
import 'package:firbird/app/back_to_home_button.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppDatabase database = ref.watch(appDatabaseProvider);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recentIdentifications),
        leading: const BackToHomeButton(),
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

          // Group records: live sessions (packageId starts with "live_") together
          final List<_HistoryItem> items = <_HistoryItem>[];
          String? lastSessionId;

          for (final IdentificationRecord record in records) {
            final bool isLive = record.packageId?.startsWith('live_') == true;

            if (isLive) {
              // Insert session header when session changes
              if (record.packageId != lastSessionId) {
                lastSessionId = record.packageId;
                // Extract date from modelVersion "🎙️ Canlı Oturum · dd.MM.yyyy HH:mm"
                final String header = record.modelVersion.contains('·')
                    ? record.modelVersion.split('·').last.trim()
                    : '';
                items.add(_HistoryItem.sessionHeader(header));
              }
              items.add(_HistoryItem.liveRecord(record));
            } else {
              lastSessionId = null;
              items.add(_HistoryItem.regularRecord(record));
            }
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (BuildContext context, int index) {
              final _HistoryItem item = items[index];

              if (item.isHeader) {
                return Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.mic, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Canlı Oturum — ${item.headerLabel}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final IdentificationRecord record = item.record!;
              final bool isLive = item.isLive;

              return Dismissible(
                key: ValueKey<int>(record.id),
                background: const ColoredBox(color: Colors.red),
                onDismissed: (_) => database.deleteIdentification(record.id),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: isLive
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                    child: Icon(
                      isLive ? Icons.mic : Icons.flutter_dash,
                      size: 18,
                      color: isLive
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSecondaryContainer,
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
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        record.confidence,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
}

class _HistoryItem {
  _HistoryItem.sessionHeader(this.headerLabel)
      : isHeader = true,
        isLive = false,
        record = null;

  _HistoryItem.liveRecord(this.record)
      : isHeader = false,
        isLive = true,
        headerLabel = '';

  _HistoryItem.regularRecord(this.record)
      : isHeader = false,
        isLive = false,
        headerLabel = '';

  final bool isHeader;
  final bool isLive;
  final String headerLabel;
  final IdentificationRecord? record;
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
      appBar: AppBar(
        title: Text(l10n.settings),
        leading: const BackToHomeButton(),
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
