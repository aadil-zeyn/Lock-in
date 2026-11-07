# Lock-in — project notes for Claude

Lock-in is an offline-first strength-training tracker for Android, built with Flutter.
Full spec: `docs/PRD-v1.0.md` plus the amendments in `docs/PRD-v1.1-changes.md` (the amendments win where they differ).

## Stack
- Flutter / Dart, Android only for now (developer is on Windows 11, VS Code + Android Studio)
- State: flutter_riverpod (no codegen; avoid StateProvider; use `.value` on AsyncValue, not `valueOrNull`)
- Navigation: go_router with `StatefulShellRoute.indexedStack` (5 tabs: Home, Workout, Food, Progress, Profile). History is a pushed route from the Workout tab
- Database: Drift + drift_flutter (SQLite). Schema in `lib/core/database/app_database.dart`
- No backend, no network calls, no runtime font downloads

## Commands
- Generate DB code after any table change: `dart run build_runner build` (the `--delete-conflicting-outputs` flag was removed in build_runner 2.17)
- Toolchain lives on D: (C: is nearly full): Flutter `D:\dev\flutter`, JDK `D:\dev\jdk-21`, Android SDK `D:\dev\android-sdk`, Gradle cache `D:\dev\gradle-home` (`GRADLE_USER_HOME`)
- Test on the `Pixel_7_API_35` emulator (x86_64). The old API 30 emulators are 32-bit x86, which current Flutter doesn't support — they show a black screen
- `lock_in_starter/` is the original Phase 1 source, kept for reference and excluded from analysis
- Checks before finishing a task: `flutter analyze` and `flutter test`
- Android release APK: `flutter build apk --release`
- Web app: `flutter build web --release --no-web-resources-cdn` (bundles CanvasKit, no CDN). Drift on web needs `web/sqlite3.wasm` and `web/drift_worker.js` matching the `sqlite3` / `drift` versions in `pubspec.lock` — re-download both from their GitHub releases after upgrading those packages
- Releases: every push to `main` touching the app runs `.github/workflows/android-release.yml` (analyze, test, signed APK, GitHub Release `v0.<run>.0`). The user installs updates with Obtainium (docs/UPDATES.md) — no USB needed. CI signs with the same debug keystore as the installed app (secret `KEYSTORE_BASE64`; public debug passwords as fallback). Never change the signing key without a backup/restore plan.
- Roadmap: `docs/ROADMAP.md`. Showcase page: `website/index.html` (built from `website/template.html` with screenshots embedded)

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
- The app is on a real phone: every schema change bumps `schemaVersion`, adds an `onUpgrade` step, dumps the schema (`dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/` then `schema generate drift_schemas/ test/generated_migrations/`) and extends `test/migration_test.dart`. Current: v3.
- Band sets store `bandLevel`, not kg; they're excluded from volume. Assisted weights are stored as negative kg.
- Food entries: kcal required, protein/name optional. Calorie tracking was added by the user's decision (the PRD listed it as out of scope).

## Design rules
- Fitness-band look (inspired by the Mi Fitness app, never copying its screens or branding): pure black, rounded tiles, activity rings, large tabular numbers (`AppText.metric*`).
- Colour: `AppColors.accent` (orange) for primary actions; each metric has a fixed colour (`AppColors.workouts/time/sets/volume/body/records/streak`); muscles are coloured by region push/pull/legs/core (`app/theme/muscle_style.dart`).
- Reuse components in `core/widgets/` before making new ones (`StatCard`, `IconBadge`, `ActivityRings`, `SelectChip`, `MuscleMap`, …); don't hard-code colours or spacing.
- Exercise "images" are the code-drawn `MuscleMap` body diagram (offline, works for custom exercises).
- State must never be shown by colour alone; support system font scaling.

## Status
- Done: workout engine, bands, Health Connect (steps read, weight read/write), weight logging, Progress charts, history import, Food tab (quick entries, favourites, daily targets), app icon.
- Next: routines, settings screens (units, rest timer, goals), backup/export, Health Connect nutrition sync.
- Built-in exercises can be archived but not edited.
- Weekly ring goals (`weeklyWorkoutGoal/MinutesGoal/SetsGoal`) default to 3 / 180 / 45 and are edited by tapping the Home "This week" rings (`weekly_goals_sheet.dart`); food targets are edited by tapping the Food rings.
- Home "This week" card is driven by `weekSummaryProvider` → `computeWeekSummary` (`dashboard/data/week_summary.dart`): pace vs goal, deltas vs last week up to the same moment, per-day minutes + main region, volume, best e1RM, goal streak. `bestLift` there is shared with the share card.
- The rest timer is in-memory (end timestamp); a system notification when it ends is not built yet.
