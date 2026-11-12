import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/app_tokens.dart';

import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../history_import/data/history_export.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';

const appVersion = '0.6';

String _feetInches(double cm) {
  final total = (cm / 2.54).round();
  return "${total ~/ 12}' ${total % 12}\"";
}

/// Shares every finished workout and custom exercise as one CSV file
/// (see [exportHistoryCsv]); Import history reads the same format.
Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final csv = await exportHistoryCsv(ref.read(databaseProvider));
    final now = DateTime.now();
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(csv)),
            mimeType: 'text/csv',
          ),
        ],
        fileNameOverrides: ['lock-in-export-$day.csv'],
      ),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final weightUnit = profile?.weightUnit ?? WeightUnit.kg;
    final lengthUnit = profile?.lengthUnit ?? LengthUnit.cm;
    final rest = profile?.restTimerSeconds ?? 90;

    void soon() => showComingSoon(context, 'Settings');
    void edit() => context.push(Routes.editProfile);
    final p = profile;
    final about = <String>[
      if (p?.heightCm != null)
        lengthUnit == LengthUnit.cm
            ? '${p!.heightCm!.round()} cm'
            : _feetInches(p!.heightCm!),
      if (p?.birthYear != null) '${DateTime.now().year - p!.birthYear!} yrs',
      if (p?.weightGoal != null) p!.weightGoal!.label,
    ];

    return TabPage(
      title: 'Profile',
      children: [
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          onTap: edit,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceHigh,
                child: Icon(
                  Icons.person_rounded,
                  color: AppColors.textSecondary,
                  size: 30,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (profile?.name?.isNotEmpty ?? false)
                          ? profile!.name!
                          : 'Add your name',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      about.isEmpty
                          ? 'Add height, age and goal'
                          : about.join(' · '),
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
        const SectionHeader('Preferences'),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.scale_outlined,
              title: 'Weight unit',
              value: weightUnit == WeightUnit.kg ? 'Kilograms' : 'Pounds',
              onTap: edit,
            ),
            _SettingsTile(
              icon: Icons.straighten_rounded,
              title: 'Measurement unit',
              value: lengthUnit == LengthUnit.cm ? 'Centimetres' : 'Inches',
              onTap: edit,
            ),
            _SettingsTile(
              icon: Icons.timer_outlined,
              title: 'Default rest timer',
              value: '${rest ~/ 60}:${(rest % 60).toString().padLeft(2, '0')}',
              onTap: soon,
            ),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              onTap: soon,
            ),
          ],
        ),
        const SectionHeader('Your data'),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.favorite_border_rounded,
              title: 'Health Connect',
              value: 'Steps & weight',
              onTap: () => context.push(Routes.healthConnect),
            ),
            _SettingsTile(
              icon: Icons.history_edu_rounded,
              title: 'Import history',
              onTap: () => context.push(Routes.importHistory),
            ),
            _SettingsTile(
              icon: Icons.ios_share_rounded,
              title: 'Export to CSV',
              value: 'Workouts & exercises',
              onTap: () => _exportCsv(context, ref),
            ),
            _SettingsTile(
              icon: Icons.backup_outlined,
              title: 'Backup & restore',
              onTap: soon,
            ),
          ],
        ),
        const SectionHeader('About'),
        _SettingsGroup(
          children: [
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'Lock-in',
              value: appVersion,
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 56),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
