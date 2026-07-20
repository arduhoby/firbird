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
  double _candidateThreshold = 0.20;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final bool enabled = await ref
          .read(appDatabaseProvider)
          .isHistoryEnabled();
      final double threshold = await ref
          .read(appDatabaseProvider)
          .candidateThreshold();
      if (mounted) {
        setState(() {
          _historyEnabled = enabled;
          _candidateThreshold = threshold;
        });
      }
    });
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
            subtitle: Text('0.1.0'),
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
