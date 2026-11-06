import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_tokens.dart';
import '../../../app/theme/muscle_style.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/widgets/widgets.dart';
import '../data/history_csv.dart';
import '../data/history_importer.dart';

/// Paste CSV from the History Logger page, preview it, import it.
class ImportHistoryScreen extends ConsumerStatefulWidget {
  const ImportHistoryScreen({super.key});

  @override
  ConsumerState<ImportHistoryScreen> createState() =>
      _ImportHistoryScreenState();
}

class _ImportHistoryScreenState extends ConsumerState<ImportHistoryScreen> {
  final _text = TextEditingController();
  ImportPreview? _preview;
  ImportResult? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(
        () => _error =
            'The clipboard is empty. Tap Copy CSV in the '
            'History Logger first.',
      );
      return;
    }
    _text.text = text;
    await _check();
  }

  Future<void> _check() async {
    final text = _text.text.trim();
    if (text.isEmpty) {
      setState(() {
        _preview = null;
        _error = 'Paste the CSV from the History Logger first.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    final parsed = parseHistoryCsv(text);
    final preview = await ref.read(historyImporterProvider).preview(parsed);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = preview;
    });
  }

  Future<void> _import() async {
    final preview = _preview;
    if (preview == null || !preview.canImport) return;
    setState(() => _busy = true);
    try {
      final result = await ref.read(historyImporterProvider).run(preview);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
        _preview = null;
        _text.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Nothing was imported: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Import history')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (_result != null) ...[
            _Success(result: _result!),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(
                  icon: Icons.history_edu_rounded,
                  color: AppColors.time,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Log past sessions in the Lock-in History Logger page, '
                    'tap Copy CSV there, then paste it here. Workouts you '
                    'already imported are skipped, so pasting twice is safe.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _text,
            minLines: 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText:
                  'date,workout,duration_min,exercise,…\n'
                  '2026-10-14,Push Day,65,Barbell Bench Press,…',
            ),
            onChanged: (_) {
              if (_preview != null || _error != null) {
                setState(() {
                  _preview = null;
                  _error = null;
                });
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Paste',
                  icon: Icons.content_paste_rounded,
                  onPressed: _busy ? null : _paste,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SecondaryButton(
                  label: 'Check',
                  icon: Icons.fact_check_outlined,
                  onPressed: _busy ? null : _check,
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _Notice(
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
              text: _error!,
            ),
          ],
          if (preview != null) ...[
            const SectionHeader('Preview'),
            _PreviewCard(preview: preview),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: _busy
                  ? 'Importing…'
                  : preview.toImport.isEmpty
                  ? 'Nothing new to import'
                  : 'Import ${preview.toImport.length} '
                        '${preview.toImport.length == 1 ? 'workout' : 'workouts'}',
              icon: Icons.download_done_rounded,
              onPressed: _busy || !preview.canImport ? null : _import,
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});
  final ImportPreview preview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final dates = preview.toImport.map((w) => w.date).toList();
    final range = dates.isEmpty
        ? null
        : dates.first == dates.last
        ? formatShortDate(dates.first)
        : '${formatShortDate(dates.first)} ${dates.first.year} – '
              '${formatShortDate(dates.last)} ${dates.last.year}';
    final problems = preview.parsed.problems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: StatCard(
                  label: 'Workouts',
                  value: '${preview.toImport.length}',
                  icon: Icons.local_fire_department_rounded,
                  color: AppColors.workouts,
                  caption: range,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: StatCard(
                  label: 'Sets',
                  value: '${preview.setCount}',
                  icon: Icons.layers_rounded,
                  color: AppColors.sets,
                  caption: 'Warm-ups included',
                ),
              ),
            ],
          ),
        ),
        if (preview.newExercises.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New custom exercises', style: text.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                for (final e in preview.newExercises)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Row(
                      children: [
                        IconBadge(
                          text: e.spec!.muscle.initials,
                          color: e.spec!.muscle.color,
                          size: 32,
                          circle: false,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '${e.name} · ${e.spec!.muscle.label}, '
                            '${e.spec!.equipment.label}',
                            style: text.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (preview.alreadyImported.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Notice(
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.textSecondary,
            text:
                '${preview.alreadyImported.length} already in Lock-in, will be skipped.',
          ),
        ],
        if (preview.unknownExercises.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Notice(
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            text:
                'Not in the library and missing muscle or equipment: '
                '${preview.unknownExercises.join(', ')}. Fill those in on '
                'the logger page and copy again.',
          ),
        ],
        if (problems.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _Notice(
            icon: Icons.warning_amber_rounded,
            color: AppColors.warning,
            text:
                '${problems.length} '
                '${problems.length == 1 ? 'line was' : 'lines were'} skipped:\n'
                '${problems.take(5).join('\n')}'
                '${problems.length > 5 ? '\n…and ${problems.length - 5} more' : ''}',
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surfaceHigh,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.result});
  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final created = result.exercisesCreated;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: AppGradients.tint(AppColors.sets),
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          const IconBadge(icon: Icons.check_rounded, color: AppColors.sets),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Imported ${result.workouts} '
                  '${result.workouts == 1 ? 'workout' : 'workouts'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${result.sets} sets'
                  '${created > 0 ? ' · $created new ${created == 1 ? 'exercise' : 'exercises'}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
