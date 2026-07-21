import 'package:firbird/data/app_database.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/inference/onnx_bird_inference_engine.dart';
import 'package:firbird/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kullanıcının model tahminini onaylayıp ya da düzeltebildiği bottom sheet.
///
/// Akış:
/// 1. İlk ekran: "Uygun mu?" → Evet / Hayır
/// 2. "Evet" → `predictionMethod: userValidated` olarak kaydeder, kapanır.
/// 3. "Hayır" → Hangi parametreyi düzeltmek istediği sorulur (cinsiyet / yaş / ikisi).
/// 4. İlgili seçiciler gösterilir → Kaydet → DB güncellenir, kapanır.
Future<SexAgeCorrectionResult?> showSexAgeCorrectionSheet(
  BuildContext context, {
  int? recordId,
  SexCategory? initialSex,
  AgeCategory? initialAge,
}) {
  return showModalBottomSheet<SexAgeCorrectionResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext ctx) => _SexAgeCorrectionSheet(
      recordId: recordId,
      initialSex: initialSex,
      initialAge: initialAge,
    ),
  );
}

class SexAgeCorrectionResult {
  const SexAgeCorrectionResult({
    required this.species,
    required this.sex,
    required this.age,
    required this.userApproved,
  });

  final SpeciesPrediction? species;
  final SexCategory? sex;
  final AgeCategory? age;

  /// true → kullanıcı "Uygun" dedi (onayladı).
  /// false → kullanıcı düzeltti.
  final bool userApproved;
}

// ---------------------------------------------------------------------------
// Akış adımları
// ---------------------------------------------------------------------------

enum _Step {
  /// "Model tahmini uygun mu?"
  approval,

  /// Hangi parametreyi düzeltmek istiyor?
  parameterSelect,

  /// Tür arama ve seçme
  speciesSelect,

  /// Cinsiyet + yaş seçicileri
  correction,
}

// ---------------------------------------------------------------------------
// Hangi parametreler düzeltilecek?
// ---------------------------------------------------------------------------

class _CorrectTarget {
  bool species = false;
  bool sex = false;
  bool age = false;
  bool get any => species || sex || age;
}

// ---------------------------------------------------------------------------
// Ana widget
// ---------------------------------------------------------------------------

class _SexAgeCorrectionSheet extends ConsumerStatefulWidget {
  const _SexAgeCorrectionSheet({
    this.recordId,
    this.initialSex,
    this.initialAge,
  });

  final int? recordId;
  final SexCategory? initialSex;
  final AgeCategory? initialAge;

  @override
  ConsumerState<_SexAgeCorrectionSheet> createState() =>
      _SexAgeCorrectionSheetState();
}

class _SexAgeCorrectionSheetState
    extends ConsumerState<_SexAgeCorrectionSheet> {
  _Step _step = _Step.approval;
  final _CorrectTarget _target = _CorrectTarget();
  SpeciesPrediction? _selectedSpecies;
  late SexCategory? _selectedSex;
  late AgeCategory? _selectedAge;
  String _speciesSearchQuery = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedSex = widget.initialSex;
    _selectedAge = widget.initialAge;
  }

  // --- İşlemler ---

  /// Kullanıcı "Uygun" dedi → onaylı kaydet.
  Future<void> _approve() async {
    setState(() => _saving = true);
    try {
      if (widget.recordId != null) {
        await ref.read(appDatabaseProvider).updateCorrection(
              widget.recordId!,
              correctedSex: _selectedSex?.name,
              correctedAge: _selectedAge?.name,
              approved: true,
            );
      }
      if (mounted) {
        Navigator.of(context).pop(
          SexAgeCorrectionResult(
            species: _selectedSpecies,
            sex: _selectedSex,
            age: _selectedAge,
            userApproved: true,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Kullanıcı düzeltmeyi kaydetti.
  Future<void> _saveCorrected() async {
    setState(() => _saving = true);
    try {
      if (widget.recordId != null) {
        await ref.read(appDatabaseProvider).updateCorrection(
              widget.recordId!,
              correctedSex: _target.sex ? _selectedSex?.name : null,
              correctedAge: _target.age ? _selectedAge?.name : null,
              correctedSpeciesId: _target.species ? _selectedSpecies?.speciesId : null,
              correctedTurkishName: _target.species ? _selectedSpecies?.turkishName : null,
              approved: false,
            );
      }
      if (mounted) {
        Navigator.of(context).pop(
          SexAgeCorrectionResult(
            species: _selectedSpecies,
            sex: _selectedSex,
            age: _selectedAge,
            userApproved: false,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Başlık
            Row(
              children: <Widget>[
                Icon(Icons.tune_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.correctionTitle, style: text.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Adıma göre içerik
            if (_step == _Step.approval) _buildApprovalStep(l10n, colors, text),
            if (_step == _Step.parameterSelect)
              _buildParameterStep(l10n, colors, text),
            if (_step == _Step.speciesSelect)
              _buildSpeciesStep(l10n, colors, text),
            if (_step == _Step.correction)
              _buildCorrectionStep(l10n, colors, text),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Adım 1: "Uygun mu?"
  // -------------------------------------------------------------------

  Widget _buildApprovalStep(
    AppLocalizations l10n,
    ColorScheme colors,
    TextTheme text,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.correctionApprovalQuestion, style: text.bodyMedium),
        const SizedBox(height: 12),
        _currentSummary(l10n, text),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _step = _Step.parameterSelect),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: Text(l10n.correctionNotCorrect),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _saving ? null : _approve,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check, size: 16),
                label: Text(l10n.correctionApprove),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Adım 2: Hangi parametreyi düzeltmek istiyor?
  // -------------------------------------------------------------------

  Widget _buildParameterStep(
    AppLocalizations l10n,
    ColorScheme colors,
    TextTheme text,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.correctionWhichParam, style: text.bodyMedium),
        const SizedBox(height: 12),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.correctionSpecies),
          value: _target.species,
          onChanged: (bool? v) => setState(() => _target.species = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.sexLabel),
          value: _target.sex,
          onChanged: (bool? v) => setState(() => _target.sex = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.ageLabel),
          value: _target.age,
          onChanged: (bool? v) => setState(() => _target.age = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = _Step.approval),
                child: Text(l10n.correctionCancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _target.any
                    ? () {
                        if (_target.species) {
                          setState(() => _step = _Step.speciesSelect);
                        } else {
                          setState(() => _step = _Step.correction);
                        }
                      }
                    : null,
                child: Text(l10n.correctionNext),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Adım 2.5: Tür Arama ve Seçme
  // -------------------------------------------------------------------

  Widget _buildSpeciesStep(
    AppLocalizations l10n,
    ColorScheme colors,
    TextTheme text,
  ) {
    final AsyncValue<List<SpeciesPrediction>> asyncSpecies =
        ref.watch(candidateSpeciesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.correctionSpeciesQuestion, style: text.titleSmall),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(
            hintText: l10n.correctionSearchSpecies,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onChanged: (String value) {
            setState(() {
              _speciesSearchQuery = value.toLowerCase();
            });
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 250, // Kaydırılabilir alan
          child: asyncSpecies.when(
            data: (List<SpeciesPrediction> candidates) {
              final List<SpeciesPrediction> filtered = candidates
                  .where((SpeciesPrediction c) =>
                      c.turkishName.toLowerCase().contains(_speciesSearchQuery) ||
                      c.scientificName.toLowerCase().contains(_speciesSearchQuery))
                  .toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('Tür bulunamadı.'));
              }
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (BuildContext ctx, int index) {
                  final SpeciesPrediction c = filtered[index];
                  final bool isSelected = _selectedSpecies?.speciesId == c.speciesId;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(c.turkishName),
                    subtitle: Text(c.scientificName),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: colors.primary)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedSpecies = c;
                      });
                    },
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace s) =>
                const Center(child: Text('Türler yüklenemedi.')),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = _Step.parameterSelect),
                child: Text(l10n.correctionCancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _selectedSpecies != null
                    ? () {
                        if (_target.sex || _target.age) {
                          setState(() => _step = _Step.correction);
                        } else {
                          _saveCorrected();
                        }
                      }
                    : null,
                child: Text(
                  (_target.sex || _target.age) ? l10n.correctionNext : l10n.correctionSave,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Adım 3: Seçiciler
  // -------------------------------------------------------------------

  Widget _buildCorrectionStep(
    AppLocalizations l10n,
    ColorScheme colors,
    TextTheme text,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (_target.sex) ...<Widget>[
          Text(l10n.correctionSexQuestion, style: text.titleSmall),
          const SizedBox(height: 8),
          _SelectionRow<SexCategory>(
            options: SexCategory.values,
            selected: _selectedSex,
            labelFor: (SexCategory s) => s.label,
            onSelected: (SexCategory? s) => setState(() => _selectedSex = s),
            colors: colors,
          ),
          const SizedBox(height: 20),
        ],
        if (_target.age) ...<Widget>[
          Text(l10n.correctionAgeQuestion, style: text.titleSmall),
          const SizedBox(height: 8),
          _SelectionRow<AgeCategory>(
            options: AgeCategory.values,
            selected: _selectedAge,
            labelFor: (AgeCategory a) => a.defaultLabel(),
            onSelected: (AgeCategory? a) => setState(() => _selectedAge = a),
            colors: colors,
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _step = _Step.parameterSelect),
                child: Text(l10n.correctionCancel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _saveCorrected,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.correctionSave),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // Yardımcı: Mevcut tahmin özeti
  // -------------------------------------------------------------------

  Widget _currentSummary(AppLocalizations l10n, TextTheme text) {
    final String sexLabel = _selectedSex?.label ?? l10n.sexUnknown;
    final String ageLabel = _selectedAge?.defaultLabel() ?? l10n.ageUnknown;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.biotech_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${l10n.sexLabel}: $sexLabel',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${l10n.ageLabel}: $ageLabel',
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Yardımcı: Seçim satırı
// ---------------------------------------------------------------------------

class _SelectionRow<T> extends StatelessWidget {
  const _SelectionRow({
    required this.options,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    required this.colors,
  });

  final List<T> options;
  final T? selected;
  final String Function(T) labelFor;
  final ValueChanged<T?> onSelected;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((T option) {
        final bool isSelected = selected == option;
        return ChoiceChip(
          label: Text(labelFor(option)),
          selected: isSelected,
          onSelected: (bool _) => onSelected(isSelected ? null : option),
          selectedColor: colors.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected ? colors.onPrimaryContainer : null,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        );
      }).toList(growable: false),
    );
  }
}
