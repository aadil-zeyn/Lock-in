# Lock-in — project notes for Claude

Lock-in is an offline-first strength-training tracker for Android, built with Flutter.
Full spec: `docs/PRD-v1.0.md` plus the amendments in `docs/PRD-v1.1-changes.md` (the amendments win where they differ).

## Stack
- Flutter / Dart, Android only for now (developer is on Windows 11, VS Code + Android Studio)
- State: flutter_riverpod (no codegen; avoid StateProvider; use `.value` on AsyncValue, not `valueOrNull`)
- Navigation: go_router with `StatefulShellRoute.indexedStack` (5 tabs: Home, Workout, History, Progress, Profile)
- Database: Drift + drift_flutter (SQLite). Schema in `lib/core/database/app_database.dart`
- No backend, no network calls, no runtime font downloads

## Commands
- Generate DB code after any table change: `dart run build_runner build --delete-conflicting-outputs`
- Checks before finishing a task: `flutter analyze` and `flutter test`

## Structure
- `lib/app/` — app root, router, theme (`theme/app_tokens.dart` holds colours, spacing, radii, number styles)
- `lib/core/` — database, utils (units, strength maths, dates), shared widgets (import `core/widgets/widgets.dart`)
- `lib/features/<feature>/{data,presentation}/` — feature-first

## Data rules (do not break)
- Weights stored in kg, lengths in cm, body fat in %. Unit preference only changes display/input (`core/utils/units.dart`).
- Exercises are archived (`archivedAt`), never hard-deleted. FKs from history use RESTRICT.
- `WorkoutExercises.exerciseNameSnapshot` is set when an exercise is added, so history survives renames.
- Only one workout with status `active` (partial unique index). Persist every set change immediately.
- Warm-up sets never count toward PRs or volume. e1RM = Epley, only for 1–12 reps.
- Bump `schemaVersion` and write a migration for any schema change once the app has real users.

## Design rules
- Dark-first, one accent colour (`AppColors.accent`), large tabular numbers (`AppText.metric*`).
- Reuse components in `core/widgets/` before making new ones; don't hard-code colours or spacing.
- State must never be shown by colour alone; support system font scaling.

## Status
- Phase 1 (foundation) done. Next: Phase 2 (custom exercise form, exercise details), then Phase 3 workout engine.
- Health Connect sync is planned later via the `health` package, opt-in from Settings.
