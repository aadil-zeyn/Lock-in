import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../body/data/body_repository.dart';
import '../data/health_providers.dart';
import '../data/health_service.dart';

/// Profile → Health Connect: connect, grant history, sync weight.
class HealthConnectScreen extends ConsumerStatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  ConsumerState<HealthConnectScreen> createState() =>
      _HealthConnectScreenState();
}

class _HealthConnectScreenState extends ConsumerState<HealthConnectScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? msg;
    try {
      msg = await action();
    } catch (e) {
      msg = 'Health Connect didn\'t respond. Try again. ($e)';
    }
    ref.invalidate(healthStatusProvider);
    ref.invalidate(weekStepsProvider);
    if (mounted) {
      setState(() {
        _busy = false;
        _message = msg;
      });
    }
  }

  Future<String?> _sync() async {
    ref.invalidate(healthStatusProvider);
    final added = await syncWeightsFromHealth(
      status: await ref.read(healthStatusProvider.future),
      health: ref.read(healthServiceProvider),
      body: ref.read(bodyRepositoryProvider),
    );
    return added == 0
        ? 'Weight is up to date.'
        : 'Added $added weight ${added == 1 ? 'entry' : 'entries'} from Health Connect.';
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(healthStatusProvider);
    final status = statusAsync.value;
    final health = ref.read(healthServiceProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconBadge(
                      icon: Icons.favorite_rounded,
                      color: AppColors.streak,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Steps and weight from your other apps',
                        style: text.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Health Connect is Android\'s on-device health store. Apps '
                  'like Mi Fitness, Google Fit and smart scales can share data '
                  'there. Lock-in reads your steps and weight, and saves the '
                  'weights you log here back to it. Nothing leaves your phone.',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Status'),
          if (status == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            _StatusRow(
              icon: Icons.phone_android_rounded,
              label: 'Health Connect on this phone',
              ok: status.availability == HealthAvailability.available,
              value: switch (status.availability) {
                HealthAvailability.available => 'Ready',
                HealthAvailability.needsUpdate => 'Needs an update',
                HealthAvailability.unavailable => 'Not available',
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _StatusRow(
              icon: Icons.link_rounded,
              label: 'Steps and weight access',
              ok: status.connected,
              value: status.connected ? 'Connected' : 'Not connected',
            ),
            const SizedBox(height: AppSpacing.sm),
            _StatusRow(
              icon: Icons.history_rounded,
              label: 'Data older than 30 days',
              ok: status.fullHistory,
              value: status.fullHistory ? 'Allowed' : 'Last 30 days only',
            ),
            const SizedBox(height: AppSpacing.xl),
            if (status.availability != HealthAvailability.available)
              PrimaryButton(
                label: status.availability == HealthAvailability.needsUpdate
                    ? 'Update Health Connect'
                    : 'Get Health Connect',
                icon: Icons.download_rounded,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        await health.install();
                        return 'Come back here after installing.';
                      }),
              )
            else if (!status.connected)
              PrimaryButton(
                label: 'Connect',
                icon: Icons.link_rounded,
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final ok = await health.connect();
                        if (!ok) {
                          return 'Access wasn\'t granted. Allow Steps and '
                              'Weight on the Health Connect screen.';
                        }
                        return _sync();
                      }),
              )
            else ...[
              PrimaryButton(
                label: 'Sync weight now',
                icon: Icons.sync_rounded,
                onPressed: _busy ? null : () => _run(_sync),
              ),
              if (!status.fullHistory) ...[
                const SizedBox(height: AppSpacing.md),
                SecondaryButton(
                  label: 'Allow full history',
                  icon: Icons.history_rounded,
                  onPressed: _busy
                      ? null
                      : () => _run(() async {
                          final ok = await health.requestFullHistory();
                          if (!ok) return 'Full history wasn\'t allowed.';
                          return _sync();
                        }),
                ),
              ],
            ],
          ],
          if (_message != null) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: AppColors.surfaceHigh,
              child: Text(_message!, style: text.bodyMedium),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Text(
            'To disconnect, open Health Connect → App permissions → Lock-in.',
            style: text.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.ok,
    required this.value,
  });
  final IconData icon;
  final String label;
  final bool ok;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          Icon(
            ok ? Icons.check_circle_rounded : Icons.remove_circle_outline,
            size: 18,
            color: ok ? AppColors.sets : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: TextStyle(
              color: ok ? AppColors.sets : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
