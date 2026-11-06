import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../body/data/body_repository.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../data/targets.dart';

/// "About you" — filled in once; drives calorie and protein targets.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final weights = ref.watch(recentBodyWeightsProvider).value;
    if (profile == null || weights == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _Form(
      profile: profile,
      latestKg: weights.isEmpty ? null : weights.first.measuredValue,
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.profile, required this.latestKg});
  final UserProfile profile;
  final double? latestKg;

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _name = TextEditingController(text: widget.profile.name ?? '');
  late final _heightCm = TextEditingController();
  late final _feet = TextEditingController();
  late final _inches = TextEditingController();
  late final _weight = TextEditingController();
  late final _birthYear = TextEditingController(
    text: widget.profile.birthYear?.toString() ?? '',
  );
  late final _steps = TextEditingController(
    text: '${widget.profile.dailyStepsGoal}',
  );

  late WeightUnit _wUnit = widget.profile.weightUnit;
  late LengthUnit _lUnit = widget.profile.lengthUnit;
  late Sex? _sex = widget.profile.sex;
  late ActivityLevel? _activity = widget.profile.activityLevel;
  late WeightGoal? _goal = widget.profile.weightGoal;
  bool _applyTargets = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fillHeight(widget.profile.heightCm);
    _fillWeight(widget.latestKg);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _heightCm,
      _feet,
      _inches,
      _weight,
      _birthYear,
      _steps,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillHeight(double? cm) {
    if (cm == null) return;
    _heightCm.text = cm.round().toString();
    final totalIn = cm / 2.54;
    var ft = totalIn ~/ 12;
    var inch = (totalIn - ft * 12).round();
    if (inch == 12) {
      ft += 1;
      inch = 0;
    }
    _feet.text = '$ft';
    _inches.text = '$inch';
  }

  void _fillWeight(double? kg) {
    _weight.text = kg == null ? '' : formatNumber(kgToDisplay(kg, _wUnit));
  }

  double? get _heightValueCm {
    if (_lUnit == LengthUnit.cm) {
      final v = double.tryParse(_heightCm.text);
      return v == null || v < 100 || v > 250 ? null : v;
    }
    final ft = int.tryParse(_feet.text);
    final inch = int.tryParse(_inches.text.isEmpty ? '0' : _inches.text);
    if (ft == null || inch == null) return null;
    final cm = (ft * 12 + inch) * 2.54;
    return cm < 100 || cm > 250 ? null : cm;
  }

  double? get _weightValueKg {
    final v = double.tryParse(_weight.text.replaceAll(',', '.'));
    if (v == null) return null;
    final kg = displayToKg(v, _wUnit);
    return kg < 20 || kg > 400 ? null : kg;
  }

  int? get _birthYearValue {
    final y = int.tryParse(_birthYear.text);
    final now = DateTime.now().year;
    return y == null || y < now - 100 || y > now - 12 ? null : y;
  }

  Targets? get _preview {
    final h = _heightValueCm, w = _weightValueKg, y = _birthYearValue;
    if (h == null || w == null || y == null) return null;
    if (_sex == null || _activity == null || _goal == null) return null;
    return computeTargets(
      sex: _sex!,
      weightKg: w,
      heightCm: h,
      age: ageOn(y, DateTime.now()),
      activity: _activity!,
      goal: _goal!,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final t = _preview;
    final steps = int.tryParse(_steps.text);
    await (db.update(db.userProfiles)..where((p) => p.id.equals(1))).write(
      UserProfilesCompanion(
        name: Value(_name.text.trim().isEmpty ? null : _name.text.trim()),
        heightCm: Value(_heightValueCm),
        weightUnit: Value(_wUnit),
        lengthUnit: Value(_lUnit),
        sex: Value(_sex),
        birthYear: Value(_birthYearValue),
        activityLevel: Value(_activity),
        weightGoal: Value(_goal),
        dailyStepsGoal: steps != null && steps >= 1000 && steps <= 50000
            ? Value(steps)
            : const Value.absent(),
        dailyKcalGoal: t != null && _applyTargets
            ? Value(t.kcal)
            : const Value.absent(),
        dailyProteinGoal: t != null && _applyTargets
            ? Value(t.protein)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );
    // A changed weight becomes today's weigh-in.
    final w = _weightValueKg;
    if (w != null &&
        (widget.latestKg == null || (w - widget.latestKg!).abs() >= 0.05)) {
      await ref.read(bodyRepositoryProvider).logWeight(w, DateTime.now());
    }
    HapticFeedback.mediumImpact();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preview = _preview;
    final year = _birthYearValue;

    Widget label(String s, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: s, style: text.titleMedium),
            if (hint != null)
              TextSpan(
                text: '  $hint',
                style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );

    TextField number(
      TextEditingController c, {
      String? suffix,
      String? hint,
      bool decimal = false,
    }) => TextField(
      controller: c,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimal ? RegExp(r'^\d{0,3}([.,]\d?)?') : RegExp(r'^\d{0,5}'),
        ),
      ],
      style: AppText.metricM,
      decoration: InputDecoration(suffixText: suffix, hintText: hint),
      onChanged: (_) => setState(() {}),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Your profile')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: PrimaryButton(
          label: _saving ? 'Saving…' : 'Save',
          icon: Icons.check_rounded,
          onPressed: _saving ? null : _save,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Name',
              counterText: '',
            ),
          ),
          label('Units'),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final u in WeightUnit.values)
                SelectChip(
                  label: unitLabel(u),
                  selected: _wUnit == u,
                  onTap: () => setState(() {
                    final kg = _weightValueKg;
                    _wUnit = u;
                    _fillWeight(kg);
                  }),
                ),
              const SizedBox(width: AppSpacing.md),
              for (final u in LengthUnit.values)
                SelectChip(
                  label: u == LengthUnit.cm ? 'cm' : 'ft / in',
                  selected: _lUnit == u,
                  onTap: () => setState(() {
                    final cm = _heightValueCm;
                    _lUnit = u;
                    _fillHeight(cm);
                  }),
                ),
            ],
          ),
          label('Height'),
          if (_lUnit == LengthUnit.cm)
            number(_heightCm, suffix: 'cm', hint: '175')
          else
            Row(
              children: [
                Expanded(
                  child: number(_feet, suffix: 'ft', hint: '5'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: number(_inches, suffix: 'in', hint: '9'),
                ),
              ],
            ),
          label('Current weight', hint: 'saved as today\'s weigh-in'),
          number(_weight, suffix: unitLabel(_wUnit), hint: '—', decimal: true),
          label('Sex', hint: 'for the calorie formula'),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final s in Sex.values)
                SelectChip(
                  label: s.label,
                  selected: _sex == s,
                  onTap: () => setState(() => _sex = s),
                ),
            ],
          ),
          label(
            'Birth year',
            hint: year == null ? null : 'age ${ageOn(year, DateTime.now())}',
          ),
          number(_birthYear, hint: '2000'),
          label('Activity outside the gym'),
          for (final a in ActivityLevel.values) ...[
            _OptionCard(
              title: a.label,
              subtitle: a.hint,
              selected: _activity == a,
              onTap: () => setState(() => _activity = a),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          label('Goal'),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final g in WeightGoal.values)
                SelectChip(
                  label: g.label,
                  selected: _goal == g,
                  color: AppColors.food,
                  onTap: () => setState(() => _goal = g),
                ),
            ],
          ),
          label('Daily steps goal'),
          number(_steps, suffix: 'steps', hint: '8000'),
          const SizedBox(height: AppSpacing.xl),
          if (preview == null)
            AppCard(
              color: AppColors.surfaceHigh,
              child: Text(
                'Fill in height, weight, sex, birth year, activity and goal to '
                'get calorie and protein targets made for you.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR DAILY TARGETS', style: AppText.overline),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _Big(
                          value: '${preview.kcal}',
                          unit: 'kcal',
                          color: AppColors.food,
                        ),
                      ),
                      Expanded(
                        child: _Big(
                          value: '${preview.protein}',
                          unit: 'g protein',
                          color: AppColors.protein,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Maintenance ≈ ${preview.maintenance} kcal. Estimates — '
                    'adjust after 2–3 weeks of weigh-ins.',
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _applyTargets,
                    onChanged: (v) => setState(() => _applyTargets = v),
                    title: const Text('Use these as my food targets'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.unit, required this.color});
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 36,
          margin: const EdgeInsets.only(right: AppSpacing.sm, top: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppText.metricL),
            Text(unit, style: AppText.unit),
          ],
        ),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.tile),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.accent : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
