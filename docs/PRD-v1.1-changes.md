# Lock-in — PRD v1.1 change notes

These amend `PRD-v1.0.md`. Everything not mentioned here stays as written.
Note: the v1.0 draft is cut off in section 11 ("Following othe…"), so the out-of-scope list needs finishing.

---

## 1. Data model changes (the important ones)

These are already implemented in `lib/core/database/app_database.dart`.

| Change | Why |
|---|---|
| **`WorkoutExercise.exercise_name_snapshot`** — copy the exercise name into the workout when it is added. | Satisfies "history survives rename/delete" without joins to a row that may be gone. |
| **Exercises are archived, never deleted** (`archived_at` nullable). Archived exercises are hidden from the library but still resolve in history and stats. | Answers the PRD's open item "define how deleted exercises are represented". FK is `RESTRICT`, so a hard delete of a used exercise is impossible. |
| **Weights stored canonically in kg, lengths in cm** (`weight_kg REAL`, `value REAL`). Unit preference only affects display/input. | Switching kg↔lb never rewrites history; no mixed-unit maths in stats. |
| **`Exercise.tracking_type`**: `weightReps`, `bodyweightReps`, `assistedBodyweight`, `duration`. Replaces the vague "exercise category". | Drives which inputs the set row shows (planks need a timer, not kg) and the volume rule below. |
| **`WorkoutSet.set_type`**: `warmup`, `normal`, `drop`, `failure`. | Warm-ups must not count toward PRs or volume, otherwise stats lie. |
| **`WorkoutSet.duration_seconds`** and **`completed_at`**. | Timed exercises; per-set timestamps enable rest analysis later. |
| **`Workout.status`**: `active`, `completed`, `discarded`, plus a partial unique index allowing **only one active workout**. | Makes "resume workout" unambiguous and recovery trivial: on launch, look for the active row. |
| **`Workout.routine_id`** nullable, `ON DELETE SET NULL`. | Know which routine a workout came from without coupling the record to the template. |
| **Rest-timer default lives on the profile** (`rest_timer_seconds`, default 90). Per-exercise override can come later. | |
| Integer auto-increment IDs. | Simple and stable. Backup/restore in MVP is replace-all, so UUIDs aren't needed yet. Revisit if sync is ever added. |

## 2. Calculation rules (fills the "clearly document" gaps)

- **Volume** = Σ(weight_kg × reps) over completed, non-warm-up sets.
  - `bodyweightReps`: volume uses latest recorded body weight at the workout date **if one exists**, otherwise the set contributes reps only (shown as "— kg"). Added weight (weighted dips) is added to body weight.
  - `assistedBodyweight`: body weight − assistance.
  - `duration`: excluded from volume; tracked as total time.
- **Estimated 1RM** = Epley: `w × (1 + reps / 30)`, only for sets of 1–12 reps (beyond that the estimate is junk). 1 rep → the weight itself.
- **PRs** are per exercise ID (variations are separate exercises, so they never mix): heaviest weight, best e1RM, most reps at a given weight, best single-session volume.
- **Muscle distribution** counts completed working sets: 1.0 for primary muscle, 0.5 for each secondary. Labelled "sets per muscle", never "growth".

## 3. Rest timer — implementation constraint

A Dart `Timer` stops when Android suspends the app. Store the timer's **end timestamp**, compute remaining time from the clock, and schedule a local notification for that timestamp. Android 12+ needs the exact-alarm permission for precise firing, and Android 13+ needs the notification permission — ask at first timer use, not at install.

## 4. Navigation tweak

Keep the 5 tabs, but:
- **Active-workout mini bar** above the bottom nav whenever a workout is active (name + elapsed time, tap to reopen). This is what actually prevents "accidental navigation discards data" from feeling scary.
- The active workout screen is a full-screen route over the tabs, not inside the Workout tab.
- The **Workout tab** is the hub: start empty / start routine / routines list / exercise library.

## 5. Logging speed details (P0)

- New set rows pre-fill from the previous set in this workout, else from the same set number last time.
- Previous performance shown inline per row ("Last: 22.5 × 10") rather than only as a block.
- Weight stepper uses the user's plate increment (default 2.5 kg / 5 lb).
- Tick to complete a set → starts rest timer (if enabled) → haptic.

## 6. Export / backup format

- **Backup**: a single JSON file (schema version + all tables), restore = replace-all after confirmation.
- **Export**: CSV of sets (date, workout, exercise, set #, type, weight, reps) for spreadsheets.
- Use Android's share sheet / file picker; no cloud dependency.

## 7. Fonts — offline-first

Don't use `google_fonts` runtime fetching. If a custom font is wanted (Inter or similar), bundle the font files as assets. The starter uses the system font with tabular figures so numbers don't jiggle while timers tick.

## 8. Testing (add to Phase 1 onwards)

- Unit tests for every calculation in section 2 (started in `test/strength_test.dart`).
- Drift migration tests once `schemaVersion` goes above 1 (`drift_dev schema dump` per version).

## 9. Section 11 — suggested completion of out-of-scope list

Social feed; following other users; leaderboards; AI-generated programmes; nutrition/calorie tracking; wearable/Health Connect sync; cloud accounts and sync; iOS build; paid subscriptions; ads.
