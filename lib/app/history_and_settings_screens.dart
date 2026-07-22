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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recentIdentifications),
        leading: const BackToHomeButton(),
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
              return ListView.builder(
                itemCount: records.length,
                itemBuilder: (BuildContext context, int index) {
                  final IdentificationRecord record = records[index];
                  return Dismissible(
                    key: ValueKey<int>(record.id),
                    background: const ColoredBox(color: Colors.red),
                    onDismissed: (_) =>
                        database.deleteIdentification(record.id),
                    child: ListTile(
                      leading: const Icon(Icons.history_outlined),
                      title: Text(record.turkishName),
                      subtitle: Text(record.scientificName),
                      trailing: Text(record.confidence),
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

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _historyEnabled = true;
  String _cropMode = 'auto';
  double _candidateThreshold = 0.05;

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
    if (mounted) {
      setState(() {
        _historyEnabled = history;
        _cropMode = cropMode;
        _candidateThreshold = threshold;
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
          ListTile(
            title: Text(l10n.activePackage),
            subtitle: const Text('Türkiye 0.1.0 · uygulamaya dahil'),
          ),
          const ListTile(
            title: Text('Uygulama sürümü'),
            subtitle: Text('0.2.3'),
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
