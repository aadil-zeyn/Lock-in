import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/units.dart';
import '../data/workout_repository.dart';

/// Column widths shared by the header and every row so they line up.
abstract final class SetCols {
  static const badge = 40.0;
  static const check = 48.0;
  static const gap = 8.0;
}

/// How a previous set reads, e.g. "60 × 8", "45 s", "Heavy × 15".
String describePrevious(PreviousSet p, TrackingType tracking, WeightUnit unit) {
  switch (tracking) {
    case TrackingType.duration:
      return p.seconds == null ? '—' : '${p.seconds} s';
    case TrackingType.bandReps:
      final band = p.band?.short ?? '—';
      return p.reps == null ? band : '$band × ${p.reps}';
    case TrackingType.weightReps:
    case TrackingType.bodyweightReps:
    case TrackingType.assistedBodyweight:
      final w = p.weightKg;
      final reps = p.reps?.toString() ?? '—';
      if (w == null || w == 0) {
        return tracking == TrackingType.weightReps ? '— × $reps' : '$reps reps';
      }
      final shown = formatNumber(kgToDisplay(w.abs(), unit));
      final sign = tracking == TrackingType.bodyweightReps
          ? '+'
          : tracking == TrackingType.assistedBodyweight
          ? '−'
          : '';
      return '$sign$shown × $reps';
  }
}

class SetHeader extends StatelessWidget {
  const SetHeader({super.key, required this.tracking, required this.unit});
  final TrackingType tracking;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {int flex = 2}) => Expanded(
      flex: flex,
      child: Text(t, textAlign: TextAlign.center, style: AppText.overline),
    );
    final u = unitLabel(unit).toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          const SizedBox(
            width: SetCols.badge,
            child: Text(
              'SET',
              textAlign: TextAlign.center,
              style: AppText.overline,
            ),
          ),
          const SizedBox(width: SetCols.gap),
          cell('LAST', flex: 3),
          const SizedBox(width: SetCols.gap),
          ...switch (tracking) {
            TrackingType.duration => [cell('SECONDS', flex: 4)],
            TrackingType.bandReps => [
              cell('BAND'),
              const SizedBox(width: SetCols.gap),
              cell('REPS'),
            ],
            TrackingType.bodyweightReps => [
              cell('+$u'),
              const SizedBox(width: SetCols.gap),
              cell('REPS'),
            ],
            TrackingType.assistedBodyweight => [
              cell('−$u'),
              const SizedBox(width: SetCols.gap),
              cell('REPS'),
            ],
            TrackingType.weightReps => [
              cell(u),
              const SizedBox(width: SetCols.gap),
              cell('REPS'),
            ],
          },
          const SizedBox(width: SetCols.gap),
          const SizedBox(width: SetCols.check),
        ],
      ),
    );
  }
}

/// One editable set. Every change is written to the database at once.
class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.tracking,
    required this.unit,
    required this.previous,
    required this.onCompleted,
  });

  final WorkoutSet set;
  final TrackingType tracking;
  final WeightUnit unit;
  final PreviousSet? previous;

  /// Called after a set is ticked (not unticked) — starts the rest timer.
  final VoidCallback onCompleted;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  WorkoutRepository get _repo => ref.read(workoutRepositoryProvider);
  bool get _assisted => widget.tracking == TrackingType.assistedBodyweight;
  bool get _timed => widget.tracking == TrackingType.duration;

  String _weightText(WorkoutSet s) {
    final kg = s.weightKg;
    if (kg == null) return '';
    return formatNumber(kgToDisplay(kg.abs(), widget.unit));
  }

  String _repsText(WorkoutSet s) =>
      (_timed ? s.durationSeconds : s.reps)?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: _weightText(widget.set));
    _reps = TextEditingController(text: _repsText(widget.set));
  }

  @override
  void didUpdateWidget(SetRow old) {
    super.didUpdateWidget(old);
    // Sync from the database unless the user is typing in that field.
    if (!_weightFocus.hasFocus) {
      final t = _weightText(widget.set);
      if (_weight.text != t) _weight.text = t;
    }
    if (!_repsFocus.hasFocus) {
      final t = _repsText(widget.set);
      if (_reps.text != t) _reps.text = t;
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  void _saveWeight(String text) {
    final v = double.tryParse(text.replaceAll(',', '.'));
    final kg = v == null ? null : displayToKg(v, widget.unit);
    _repo.updateSet(
      widget.set.id,
      weightKg: Value(kg == null ? null : (_assisted ? -kg : kg)),
    );
  }

  void _saveReps(String text) {
    final v = int.tryParse(text);
    _repo.updateSet(
      widget.set.id,
      reps: _timed ? const Value.absent() : Value(v),
      seconds: _timed ? Value(v) : const Value.absent(),
    );
  }

  Future<void> _toggle() async {
    final s = widget.set;
    if (!s.isCompleted) {
      final hasCount = _timed
          ? (s.durationSeconds ?? 0) > 0
          : (s.reps ?? 0) > 0;
      if (!hasCount) {
        // Nothing to tick yet: take last time's numbers if there are any.
        final p = widget.previous;
        final prevCount = _timed ? p?.seconds : p?.reps;
        if (p != null && (prevCount ?? 0) > 0) {
          await _repo.updateSet(
            s.id,
            weightKg: Value(p.weightKg),
            reps: Value(p.reps),
            seconds: Value(p.seconds),
            band: Value(p.band),
          );
        } else {
          HapticFeedback.selectionClick();
          _repsFocus.requestFocus();
          return;
        }
      }
      HapticFeedback.mediumImpact();
      await _repo.setCompleted(s.id, true);
      widget.onCompleted();
    } else {
      HapticFeedback.selectionClick();
      await _repo.setCompleted(s.id, false);
    }
  }

  Future<void> _pickBand() async {
    final picked = await showModalBottomSheet<BandLevel>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Which band?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            for (final b in BandLevel.values)
              ListTile(
                leading: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: b.color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    b.short,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
                title: Text(b.label),
                trailing: widget.set.bandLevel == b
                    ? const Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(context, b),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (picked != null) {
      await _repo.updateSet(widget.set.id, band: Value(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.set;
    final done = s.isCompleted;
    final prev = widget.previous;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: done ? AppColors.sets.withValues(alpha: 0.12) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: SetCols.badge,
            child: _TypeBadge(set: s),
          ),
          const SizedBox(width: SetCols.gap),
          Expanded(
            flex: 3,
            child: Text(
              prev == null
                  ? '—'
                  : describePrevious(prev, widget.tracking, widget.unit),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: SetCols.gap),
          if (_timed)
            Expanded(
              flex: 4,
              child: _NumberField(
                controller: _reps,
                focusNode: _repsFocus,
                hint: prev?.seconds?.toString() ?? 's',
                decimal: false,
                onChanged: _saveReps,
                label: 'Set ${s.setNumber} seconds',
              ),
            )
          else ...[
            Expanded(
              flex: 2,
              child: widget.tracking == TrackingType.bandReps
                  ? _BandButton(band: s.bandLevel, onTap: _pickBand)
                  : _NumberField(
                      controller: _weight,
                      focusNode: _weightFocus,
                      hint: prev?.weightKg == null
                          ? (widget.tracking == TrackingType.weightReps
                                ? unitLabel(widget.unit)
                                : '0')
                          : formatNumber(
                              kgToDisplay(prev!.weightKg!.abs(), widget.unit),
                            ),
                      decimal: true,
                      onChanged: _saveWeight,
                      label: 'Set ${s.setNumber} weight',
                    ),
            ),
            const SizedBox(width: SetCols.gap),
            Expanded(
              flex: 2,
              child: _NumberField(
                controller: _reps,
                focusNode: _repsFocus,
                hint: prev?.reps?.toString() ?? 'reps',
                decimal: false,
                onChanged: _saveReps,
                label: 'Set ${s.setNumber} reps',
              ),
            ),
          ],
          const SizedBox(width: SetCols.gap),
          SizedBox(
            width: SetCols.check,
            height: 44,
            child: Semantics(
              label: done
                  ? 'Set ${s.setNumber} done, tap to undo'
                  : 'Mark set ${s.setNumber} done',
              button: true,
              child: Material(
                color: done ? AppColors.sets : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _toggle,
                  child: Icon(
                    Icons.check_rounded,
                    color: done ? AppColors.onAccent : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Set number, or W / D / F for warm-up, drop and failure sets.
/// Tap to change the type or delete the set.
class _TypeBadge extends ConsumerWidget {
  const _TypeBadge({required this.set});
  final WorkoutSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (text, color) = switch (set.setType) {
      SetType.warmup => ('W', AppColors.warning),
      SetType.drop => ('D', AppColors.volume),
      SetType.failure => ('F', AppColors.danger),
      SetType.normal => ('${set.setNumber}', AppColors.textPrimary),
    };
    return PopupMenuButton<Object>(
      tooltip: 'Set ${set.setNumber}: ${set.setType.label}',
      onSelected: (v) {
        final repo = ref.read(workoutRepositoryProvider);
        if (v is SetType) {
          repo.updateSet(set.id, type: Value(v));
        } else {
          repo.deleteSet(set.id);
        }
      },
      itemBuilder: (context) => [
        for (final t in SetType.values)
          CheckedPopupMenuItem(
            value: t,
            checked: set.setType == t,
            child: Text(t.label),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete set', style: TextStyle(color: AppColors.danger)),
        ),
      ],
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

class _BandButton extends StatelessWidget {
  const _BandButton({required this.band, required this.onTap});
  final BandLevel? band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = band;
    return Material(
      color: b == null ? AppColors.surfaceHigh : b.color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              b?.label ?? 'Band',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: b == null ? AppColors.textTertiary : b.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.decimal,
    required this.onChanged,
    required this.label,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final bool decimal;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Semantics(
        label: label,
        textField: true,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'^\d{0,4}([.,]\d{0,2})?') : RegExp(r'^\d{0,4}'),
            ),
          ],
          textInputAction: TextInputAction.next,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            fillColor: AppColors.surfaceHigh,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
