import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/units.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../../health/data/health_providers.dart';
import '../data/body_repository.dart';

/// Bottom sheet to log today's (or a past) body weight.
Future<void> showLogWeightSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _LogWeightSheet(),
  );
}

class _LogWeightSheet extends ConsumerStatefulWidget {
  const _LogWeightSheet();

  @override
  ConsumerState<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends ConsumerState<_LogWeightSheet> {
  final _value = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Start from the latest entry so a small change is a quick edit.
    final latest = ref.read(recentBodyWeightsProvider).value;
    final unit =
        ref.read(userProfileProvider).value?.weightUnit ?? WeightUnit.kg;
    if (latest != null && latest.isNotEmpty) {
      _value.text = formatNumber(kgToDisplay(latest.first.measuredValue, unit));
    }
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _isToday(picked) ? now.hour : 8,
          _isToday(picked) ? now.minute : 0,
        );
      });
    }
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> _save() async {
    final unit =
        ref.read(userProfileProvider).value?.weightUnit ?? WeightUnit.kg;
    final v = double.tryParse(_value.text.replaceAll(',', '.'));
    final kg = v == null ? null : displayToKg(v, unit);
    if (kg == null || kg < 20 || kg > 400) {
      setState(
        () => _error =
            'Enter a weight between '
            '${formatNumber(kgToDisplay(20, unit))} and '
            '${formatNumber(kgToDisplay(400, unit))} ${unitLabel(unit)}',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await ref.read(bodyRepositoryProvider).logWeight(kg, _date);
    // Share it with Health Connect when connected; never block on it.
    final status = ref.read(healthStatusProvider).value;
    if (status?.canWriteWeight ?? false) {
      try {
        await ref.read(healthServiceProvider).writeWeight(kg, _date);
      } catch (_) {}
    }
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final unit =
        ref.watch(userProfileProvider).value?.weightUnit ?? WeightUnit.kg;
    final text = Theme.of(context).textTheme;
    final connected =
        ref.watch(healthStatusProvider).value?.canWriteWeight ?? false;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.monitor_weight_rounded,
                color: AppColors.body,
              ),
              const SizedBox(width: AppSpacing.md),
              Text('Log body weight', style: text.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _value,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d{0,3}([.,]\d{0,2})?'),
              ),
            ],
            style: AppText.metricXL.copyWith(color: AppColors.body),
            decoration: InputDecoration(
              suffixText: unitLabel(unit),
              suffixStyle: AppText.unit,
              hintText: '0.0',
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            label: _isToday(_date) ? 'Today' : formatLongDate(_date),
            icon: Icons.calendar_today_rounded,
            onPressed: _pickDate,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: _saving ? 'Saving…' : 'Save',
            icon: Icons.check_rounded,
            onPressed: _saving ? null : _save,
          ),
          if (connected) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Also saved to Health Connect.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
