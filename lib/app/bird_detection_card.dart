import 'package:firbird/app/bird_photo.dart';
import 'package:firbird/app/detection_evidence_sheet.dart';
import 'package:firbird/audio/audio_evidence_assessment.dart';
import 'package:firbird/detection/detection_record.dart';
import 'package:firbird/detection/detection_score_aggregate.dart';
import 'package:firbird/inference/bird_inference_engine.dart';
import 'package:firbird/inference/temporal_detection_context.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BirdDetectionDeck extends StatefulWidget {
  const BirdDetectionDeck({
    required this.records,
    super.key,
    this.focusedIndex = 0,
    this.onFocusChanged,
    this.onSeek,
    this.onVerdict,
    this.onAudioReview,
    this.isRareAlertActive,
    this.isRareAlertPulse = false,
    this.height = 500,
  });

  final List<DetectionRecord> records;
  final int focusedIndex;
  final ValueChanged<int>? onFocusChanged;
  final ValueChanged<int>? onSeek;
  final void Function(int index, DetectionVerdict verdict)? onVerdict;
  final Future<void> Function(int index, AudioReviewVerdict verdict)?
  onAudioReview;
  final bool Function(int index)? isRareAlertActive;
  final bool isRareAlertPulse;
  final double height;

  @override
  State<BirdDetectionDeck> createState() => _BirdDetectionDeckState();
}

class _BirdDetectionDeckState extends State<BirdDetectionDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController.unbounded(
    vsync: this,
    value: _safeIndex(widget.focusedIndex).toDouble(),
  );
  double _dragStart = 0;
  double _dragDistance = 0;

  int _safeIndex(int index) =>
      widget.records.isEmpty ? 0 : index.clamp(0, widget.records.length - 1);

  int _wrap(int index) => index % widget.records.length;

  @override
  void didUpdateWidget(covariant BirdDetectionDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Audio position ticks must not reset a gesture already in progress.
    if (oldWidget.focusedIndex != widget.focusedIndex ||
        oldWidget.records.length != widget.records.length) {
      if (widget.records.isNotEmpty) {
        _focus(_safeIndex(widget.focusedIndex), notify: false);
      }
    }
  }

  void _focus(int index, {bool notify = true}) {
    if (widget.records.isEmpty) return;
    final int target = _wrap(index);
    final int length = widget.records.length;
    final double current = _motion.value;
    double destination = target.toDouble();
    destination += ((current - destination) / length).round() * length;
    _motion.animateTo(
      destination,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
    );
    if (notify) widget.onFocusChanged?.call(target);
  }

  Future<void> _review(int index, AudioReviewVerdict verdict) async {
    await widget.onAudioReview?.call(index, verdict);
    if (mounted && widget.records.length > 1) _focus(index + 1);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double height = constraints.maxHeight;
          final double rowHeight = (height * 0.10).clamp(38.0, 48.0);
          const double gap = 6;
          final double expandedHeight = (height - 4 * (rowHeight + gap) - 16)
              .clamp(100.0, 320.0);
          final double center = height / 2;
          double topFor(double offset) {
            if (offset >= 1) {
              return center +
                  expandedHeight / 2 +
                  gap +
                  (offset - 1) * (rowHeight + gap);
            }
            if (offset <= -1) {
              return center -
                  expandedHeight / 2 -
                  gap -
                  rowHeight +
                  (offset + 1) * (rowHeight + gap);
            }
            final double focusTop = center - expandedHeight / 2;
            final double neighborTop = offset >= 0
                ? center + expandedHeight / 2 + gap
                : center - expandedHeight / 2 - gap - rowHeight;
            return focusTop + (neighborTop - focusTop) * offset.abs();
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) {
              _motion.stop();
              _dragStart = _motion.value;
              _dragDistance = 0;
            },
            onVerticalDragUpdate: (details) {
              _dragDistance += details.delta.dy;
              _motion.value = _dragStart - _dragDistance / 150;
            },
            onVerticalDragEnd: (details) {
              final double speed = details.primaryVelocity ?? 0;
              int target = _motion.value.round();
              if ((_motion.value - _dragStart).abs() < 0.5 &&
                  speed.abs() > 180) {
                target = _dragStart.round() + (speed < 0 ? 1 : -1);
              }
              _focus(target);
            },
            onVerticalDragCancel: () => _focus(_motion.value.round()),
            child: AnimatedBuilder(
              animation: _motion,
              builder: (context, _) {
                final int length = widget.records.length;
                final int focused = _wrap(_motion.value.round());
                final List<(int, double)> visible = [];
                for (int index = 0; index < length; index++) {
                  double offset = index - _motion.value;
                  offset -= (offset / length).round() * length;
                  if (offset.abs() <= 3) visible.add((index, offset));
                }
                // Paint the front card last; every species retains its own key.
                visible.sort((a, b) => b.$2.abs().compareTo(a.$2.abs()));
                return ClipRect(
                  child: Stack(
                    children: [
                      for (final entry in visible)
                        Positioned(
                          key: ValueKey(widget.records[entry.$1].speciesId),
                          top: topFor(entry.$2),
                          left: 4 + entry.$2.abs().clamp(0.0, 2.0) * 9,
                          right: 4 + entry.$2.abs().clamp(0.0, 2.0) * 9,
                          height:
                              rowHeight +
                              (expandedHeight - rowHeight) *
                                  (1 - entry.$2.abs()).clamp(0.0, 1.0),
                          child: Transform(
                            key: ValueKey('deck-transform-${entry.$1}'),
                            alignment: entry.$2 < 0
                                ? Alignment.bottomCenter
                                : Alignment.topCenter,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..translateByDouble(
                                0,
                                0,
                                -24 * entry.$2.abs().clamp(0.0, 2.0),
                                1,
                              )
                              ..rotateX(entry.$2.clamp(-1.0, 1.0) * 0.18),
                            child: Material(
                              elevation:
                                  2 + 16 * (1 - entry.$2.abs()).clamp(0.0, 1.0),
                              shadowColor: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(16),
                              color: Theme.of(context).colorScheme.surface,
                              clipBehavior: Clip.antiAlias,
                              child: _SwipeReviewCard(
                                onReview:
                                    entry.$1 != focused ||
                                        widget.onAudioReview == null
                                    ? null
                                    : (verdict) => _review(entry.$1, verdict),
                                child: ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.topCenter,
                                    minHeight: entry.$1 == focused
                                        ? expandedHeight
                                        : rowHeight,
                                    maxHeight: entry.$1 == focused
                                        ? expandedHeight
                                        : rowHeight,
                                    child: BirdDetectionCard(
                                      key: ValueKey(
                                        'detection-${entry.$1 == focused ? 'expanded' : 'row'}-${entry.$1}',
                                      ),
                                      record: widget.records[entry.$1],
                                      isExpanded: entry.$1 == focused,
                                      isHighlighted: entry.$1 == focused,
                                      isRareAlertActive:
                                          widget.isRareAlertActive?.call(
                                            entry.$1,
                                          ) ??
                                          false,
                                      isRareAlertPulse: widget.isRareAlertPulse,
                                      onToggleExpanded: entry.$1 == focused
                                          ? null
                                          : () => _focus(entry.$1),
                                      onSeek: widget.onSeek == null
                                          ? null
                                          : () => widget.onSeek!(entry.$1),
                                      onVerdict: widget.onVerdict == null
                                          ? null
                                          : (verdict) => widget.onVerdict!(
                                              entry.$1,
                                              verdict,
                                            ),
                                      onAudioReview:
                                          widget.onAudioReview == null
                                          ? null
                                          : (verdict) =>
                                                _review(entry.$1, verdict),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SwipeReviewCard extends StatefulWidget {
  const _SwipeReviewCard({required this.child, this.onReview});

  final Widget child;
  final Future<void> Function(AudioReviewVerdict verdict)? onReview;

  @override
  State<_SwipeReviewCard> createState() => _SwipeReviewCardState();
}

class _SwipeReviewCardState extends State<_SwipeReviewCard> {
  double _dragX = 0;
  bool _settling = false;

  Future<void> _finish(double width) async {
    if (_dragX.abs() < width * 0.22 || widget.onReview == null) {
      setState(() => _dragX = 0);
      return;
    }
    final AudioReviewVerdict verdict = _dragX > 0
        ? AudioReviewVerdict.audible
        : AudioReviewVerdict.inaudible;
    setState(() {
      _settling = true;
      _dragX = (_dragX.sign) * width * 1.25;
    });
    await Future<void>.delayed(const Duration(milliseconds: 180));
    await widget.onReview!(verdict);
    if (!mounted) return;
    setState(() {
      _settling = false;
      _dragX = 0;
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double width = constraints.maxWidth;
      final double approval = (width <= 0 ? 0.0 : _dragX / width)
          .clamp(-1.0, 1.0)
          .toDouble();
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: widget.onReview == null || _settling
            ? null
            : (DragUpdateDetails details) =>
                  setState(() => _dragX += details.delta.dx),
        onHorizontalDragEnd: widget.onReview == null || _settling
            ? null
            : (_) => _finish(width),
        child: AnimatedContainer(
          duration: _settling || _dragX == 0
              ? const Duration(milliseconds: 180)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          transformAlignment: Alignment.center,
          transform: Matrix4.translationValues(_dragX, 0, 0)
            ..rotateZ(approval * 0.08),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              widget.child,
              if (_dragX.abs() > 12)
                Positioned(
                  top: 24,
                  left: _dragX > 0 ? 24 : null,
                  right: _dragX < 0 ? 24 : null,
                  child: Transform.rotate(
                    angle: approval * -0.08,
                    child: _SwipeStamp(
                      approved: _dragX > 0,
                      opacity: approval.abs(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp({required this.approved, required this.opacity});

  final bool approved;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final Color color = approved
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            approved ? 'BU KUŞ' : 'BU KUŞ DEĞİL',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }
}

class BirdDetectionCard extends StatelessWidget {
  const BirdDetectionCard({
    required this.record,
    super.key,
    this.isHighlighted = false,
    this.isExpanded = true,
    this.isRareAlertActive = false,
    this.isRareAlertPulse = false,
    this.onToggleExpanded,
    this.onSeek,
    this.onVerdict,
    this.onAudioReview,
  });

  final DetectionRecord record;
  final bool isHighlighted;
  final bool isExpanded;
  final bool isRareAlertActive;
  final bool isRareAlertPulse;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onSeek;
  final ValueChanged<DetectionVerdict>? onVerdict;
  final Future<void> Function(AudioReviewVerdict verdict)? onAudioReview;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool pendingTemporalReview =
        record.verdict != DetectionVerdict.correct &&
        record.audioReviewVerdict != AudioReviewVerdict.audible &&
        temporalContextForSpecies(
              scientificName: record.scientificName,
              moment: record.detectedAt,
              latitude: record.latitude,
              longitude: record.longitude,
            ).confidenceMultiplier <
            0.7;
    final Color expandedColor = pendingTemporalReview
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.primaryContainer;
    final int score =
        record.evidence?.finalScore ??
        DetectionScoreAggregate.combinedPercentFor(
          averageConfidence: record.modelConfidence,
          independentEventCount: record.repeatedHits,
          pointsPerAdditionalEvent: record.repetitionSupportPerHit,
        );
    final Color scoreColor = pendingTemporalReview
        ? Colors.orange
        : score >= 60
        ? Colors.green
        : score >= 40
        ? Colors.orange
        : theme.colorScheme.error;
    final Color categoryBorder = pendingTemporalReview
        ? Colors.orange
        : switch (record.statusCategory) {
            SpeciesStatusCategory.localOrMigratory => Colors.green,
            SpeciesStatusCategory.outOfRegion => Colors.grey,
            SpeciesStatusCategory.rare => theme.colorScheme.outlineVariant,
          };
    final bool showRarePulse =
        record.statusCategory == SpeciesStatusCategory.rare &&
        isRareAlertActive &&
        isRareAlertPulse;
    final bool isRejected =
        record.verdict == DetectionVerdict.incorrect ||
        record.audioReviewVerdict == AudioReviewVerdict.inaudible;

    Future<void> showEvidence() async {
      final DetectionVerdict? verdict = await showDetectionEvidenceSheet(
        context,
        record,
      );
      if (verdict != null) onVerdict?.call(verdict);
    }

    final Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: isExpanded
            ? expandedColor
            : theme.colorScheme.surfaceContainerLow,
        gradient: isExpanded
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  expandedColor,
                  Color.lerp(expandedColor, theme.colorScheme.surface, 0.55)!,
                ],
              )
            : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: categoryBorder,
          width: isExpanded ? 1.5 : 0.7,
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
        onTap: onToggleExpanded ?? showEvidence,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: Padding(
              key: ValueKey<bool>(isExpanded),
              padding: EdgeInsets.all(isExpanded ? 10 : 6),
              child: isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            BirdPhoto(
                              speciesId: record.speciesId,
                              scientificName: record.scientificName,
                              imageUrl: record.thumbnailUrl,
                              size: 72,
                              borderRadius: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    record.turkishName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    record.scientificName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
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
                                          DetectionSource.audioFile =>
                                            'Ses dosyası',
                                          DetectionSource.photo => 'Fotoğraf',
                                          DetectionSource.replay => 'Replay',
                                        },
                                        color: theme.colorScheme.tertiary,
                                      ),
                                      if (record.repeatedHits > 1)
                                        _DetectionBadge(
                                          label:
                                              '${record.repeatedHits}× duyuldu',
                                          color: pendingTemporalReview
                                              ? Colors.orange
                                              : Colors.green,
                                        ),
                                      if (pendingTemporalReview)
                                        const _DetectionBadge(
                                          label: 'Saat dışı · onay bekliyor',
                                          color: Colors.orange,
                                        ),
                                      if (record.statusCategory ==
                                          SpeciesStatusCategory.rare)
                                        _DetectionBadge(
                                          label: 'Nadir Tür',
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      if (isHighlighted)
                                        const _DetectionBadge(
                                          label: 'İncelenen',
                                          color: Colors.blue,
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
                                    icon: const Icon(
                                      Icons.play_circle_fill_rounded,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                if (record.audioEvidence != null) ...<Widget>[
                                  const SizedBox(height: 5),
                                  _DetectionInfoLine(
                                    icon: Icons.graphic_eq_rounded,
                                    text: _audioEvidenceLabel(
                                      record.audioEvidence!,
                                    ),
                                  ),
                                ],
                                if (record.regionalSupport != null) ...<Widget>[
                                  const SizedBox(height: 5),
                                  _DetectionInfoLine(
                                    icon: Icons.location_on_outlined,
                                    text:
                                        'Yakın çevre gözlemleri: ${_regionalSupportLabel(record.regionalSupport!)}',
                                  ),
                                ],
                                if (record.temporalContext != null) ...<Widget>[
                                  const SizedBox(height: 4),
                                  _DetectionInfoLine(
                                    icon: Icons.schedule_outlined,
                                    text: record.temporalContext!,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (onAudioReview != null) ...<Widget>[
                          const SizedBox(height: 5),
                          AudioEvidenceReviewControls(
                            expanded: true,
                            selected: record.audioReviewVerdict,
                            onChanged: onAudioReview!,
                          ),
                        ],
                        if (onVerdict != null &&
                            onToggleExpanded != null) ...<Widget>[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: showEvidence,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Kanıtı incele ve doğrula'),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      children: <Widget>[
                        BirdPhoto(
                          speciesId: record.speciesId,
                          scientificName: record.scientificName,
                          imageUrl: record.thumbnailUrl,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            record.turkishName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              decoration: isRejected
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (isRejected)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: _DetectionBadge(
                              label: 'Bu kuş değil',
                              color: Colors.grey,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          '%$score',
                          style: TextStyle(
                            color: scoreColor,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.expand_more, size: 20),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    if (!isRejected) return card;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
      child: card,
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

String _audioReviewActionLabel(AudioReviewVerdict verdict) => switch (verdict) {
  AudioReviewVerdict.audible => 'Bu kuş',
  AudioReviewVerdict.uncertain => 'Emin değilim',
  AudioReviewVerdict.inaudible => 'Bu kuş değil',
};

String _regionalSupportLabel(String value) => switch (value) {
  'strong' => 'güçlü destek',
  'moderate' => 'orta destek',
  'weak' => 'zayıf destek',
  'none' => 'yakın kayıt yok — dinleyerek doğrula',
  _ => 'yakın kayıt bulunamadı',
};

class _DetectionInfoLine extends StatelessWidget {
  const _DetectionInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(
        icon,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ],
  );
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
