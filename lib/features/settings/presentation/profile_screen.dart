import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/widgets/widgets.dart';
import '../../dashboard/data/dashboard_providers.dart';

const appVersion = '0.1.0 (Phase 1)';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final weightUnit = profile?.weightUnit ?? WeightUnit.kg;
    final lengthUnit = profile?.lengthUnit ?? LengthUnit.cm;
    final rest = profile?.restTimerSeconds ?? 90;

    void soon() => showComingSoon(context, 'Settings');

    return TabPage(
      title: 'Profile',
      children: [
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          onTap: soon,
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
                      'Height, units and preferences',
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
              onTap: soon,
            ),
            _SettingsTile(
              icon: Icons.straighten_rounded,
              title: 'Measurement unit',
              value: lengthUnit == LengthUnit.cm ? 'Centimetres' : 'Inches',
              onTap: soon,
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
              icon: Icons.ios_share_rounded,
              title: 'Export to CSV',
              onTap: soon,
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
