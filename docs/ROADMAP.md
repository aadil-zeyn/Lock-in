# Lock-in — Roadmap

Versions build on the PRD phases (`PRD-v1.0.md` + `PRD-v1.1-changes.md`). Each version ships something usable, and each has a **Design** line, because looking good is a requirement, not a polish step.

Legend: ✅ done · 🔨 next · ⏳ planned · 💡 idea (needs a decision first)

---

## ✅ v0.1 — Foundation (PRD Phase 1)
Flutter project, Drift database with the full schema, 52-exercise seed library, 5-tab navigation, design tokens, shared components.

## ✅ v0.2 — Exercise library + band-style look (PRD Phase 2)
- Library search, muscle **and** equipment filters, exercise count.
- Create / edit custom exercises (validation, duplicate-name check, unsaved-changes guard).
- Exercise details with front/back **muscle map**, archive / restore with Undo.
- **Design:** pure-black band style, weekly activity rings, gradient start card, per-metric colours, push/pull/legs/core muscle colours.

---

## 🔨 v0.3 — Workout engine (PRD Phase 3, the most important release)
- Start an empty workout from Home or the Workout tab; rename it.
- **Active workout screen** as a full-screen route + **mini bar** above the tab bar while active (name + live timer).
- Exercise picker (reuses the library with search + filters, multi-select).
- **Set rows**: weight/reps (or time for duration exercises), steppers using the plate increment, set types (warm-up, working, drop, failure).
- Tick to complete → haptic + optional rest timer. Every change saved immediately.
- New sets pre-fill from the previous set, else from last time; **"Last: 22.5 × 10"** shown inline.
- **Rest timer** stored as an end timestamp (survives the app being killed), local notification when done (permission asked at first use).
- Reorder / remove exercises; add / remove sets; per-exercise notes.
- **Finish** → summary (duration, sets, volume, PRs hit) → history record. **Discard** with confirmation.
- Crash/restart recovery: on launch, reopen the active workout.
- **Design:** big tappable number fields, satisfying set-complete animation (row fills with the sets colour + tick), circular rest-timer ring in the time colour, summary screen with rings filling up.

## ⏳ v0.4 — History & routines (PRD Phase 4)
- History list grouped by week/month: name, date, duration, exercises, sets, volume.
- Workout details; edit past sets; delete with confirmation; search by name, filter by date.
- **Routines**: create, name, add/reorder exercises, suggested sets; start a workout from a routine (routine edits never touch past workouts).
- **Design:** calendar heat-strip (trained days glow orange), routine cards showing the muscle map of everything they train.

## ⏳ v0.5 — Progress & records (PRD Phase 5a)
- Per-exercise charts: best weight, e1RM (Epley, 1–12 reps), reps, volume; ranges 1M / 3M / 6M / 1Y / All.
- **Personal records**: heaviest, best e1RM, most reps at a weight, best session volume — with a PR badge in the workout and on Home.
- Training volume by week / month / exercise / muscle; weekly frequency and duration.
- **Muscle distribution** heat map on the body diagram ("sets per muscle", 1.0 primary / 0.5 secondary).
- **Design:** smooth gradient line charts, PR "trophy" moment with a short celebration animation, the muscle map reused as a heat map.

## ⏳ v0.6 — Body tracking (PRD Phase 5b)
- One-tap body-weight log from Home; full measurements (body fat, waist, chest, arms, thighs, hips).
- Edit / delete entries, history list, charts with a 7-day trend line (smooths daily noise).
- **Design:** body-weight tile becomes a live sparkline; cyan body colour throughout.

## ⏳ v0.7 — Settings & your data
- Profile: name, height, photo (optional).
- Units kg/lb and cm/in, plate increment, rest-timer default, **weekly ring goals** (workouts / minutes / sets).
- **Backup & restore** (single JSON file, replace-all after confirmation) and **CSV export** of sets, via the Android share sheet.
- About page, app version, licences.
- **Design:** grouped settings cards with coloured icon badges, live preview of the rings when changing goals.

## ⏳ v0.8 — Polish & release candidate (PRD Phase 6)
- Onboarding (name, units, goals) in 3 screens.
- App icon + splash screen, bundled font (e.g. Inter) for a more premium feel — no runtime downloads.
- Animations pass (page transitions, number roll-ups, ring fills), haptics pass.
- Accessibility pass: font scaling to 200%, TalkBack labels, contrast check, 48 dp targets.
- Database migration tests (`schemaVersion` 2+), performance check with 2 years of fake data.
- Release signing key, smaller per-device APKs / App Bundle.

## ⏳ v1.0 — Launch
- Play Store listing (screenshots from the showcase page), privacy policy (data never leaves the device).
- Bug-fix buffer.

---

## After 1.0

### ⏳ v1.1 — Smarter training
- **Progression hints**: "Last time 3×10 at 20 kg — try 22.5 kg" (double-progression rule).
- Plate calculator (which plates on each side), warm-up set generator, 1RM calculator.
- Supersets / circuits; per-exercise rest-timer override.

### ⏳ v1.2 — Stay consistent
- Home-screen **widget** with this week's rings.
- Streaks (weeks hitting the goal), gentle workout reminders on chosen days.
- Weekly recap card ("4 workouts, +5% volume, 2 PRs").

### ⏳ v1.3 — Health Connect (opt-in)
- Write completed workouts and body weight to Health Connect via the `health` package; read body weight from a smart scale. Off by default, enabled in Settings.

### 🔨 Exercise photos
- ✅ Start/end photos for 62 built-ins (public-domain Free Exercise DB), alternating like a slow GIF; thumbnails in the library.
- ⏳ Photos for the remaining band moves, and an optional photo for custom exercises.

### ⏳ v1.4 — Themes
- Light theme and a few accent palettes, following the system setting by default.

### ⏳ Accounts & cloud backup (to do later)
Goal: never lose workout history if the phone is lost or reset. The app stays offline-first; the cloud only holds a backup copy.
- [ ] Decide the goal: backup only, or also using the app on a second device (decides backup vs full sync).
- [ ] Create a Firebase project; register the app's signing-key SHA-1 (same debug keystore CI uses).
- [ ] Add `google-services.json` to CI as a secret (like `KEYSTORE_BASE64`); keep it out of git.
- [ ] **Google sign-in** with Firebase Auth (optional — the app must keep working signed out).
- [ ] **Automatic cloud backup**: upload a database snapshot (Firebase Storage or Google Drive) after each finished workout / daily.
- [ ] **Restore on a new phone**: sign in → pick a backup → replace-all after confirmation; runs migrations if the backup is an older `schemaVersion`.
- [ ] Test a real restore before relying on it.
- [ ] Update the privacy policy (data no longer "never leaves the device" when backup is on).
- Not planned: **SAML** (for company logins, needs the paid Identity Platform tier). **Live multi-device sync** (Firestore + conflict handling) only if a second device becomes a real need — weeks of work.

### 💡 Ideas that need a decision first
- **Wear OS / band companion** — log sets from the wrist (large project).
- **Cloud sync between phone and web** — the PRD keeps the MVP offline with no accounts; sync would need a backend and sign-in. Until then, move data with backup/restore. See *Accounts & cloud backup* above for the first step.
- iOS build — Flutter makes it possible, but needs a Mac to build.

---

## Web app track (runs alongside)
- ✅ **w0.2** — Same Flutter code builds for the browser. Data is stored locally in the browser (SQLite in IndexedDB/OPFS), phone-width layout centred on large screens.
- ⏳ **w0.3+** — Gets each feature as it lands on Android. Rest-timer alerts use browser notifications.
- ⏳ Installable as a PWA (add to home screen / desktop, works offline).
- ⏳ Move data between phone and web with backup/restore (v0.7).
- 💡 A wider two-column desktop layout (charts beside history) once v0.5 exists.

## Showcase page
- ✅ Landing page with real screenshots, feature list and this roadmap.
- ⏳ Refresh screenshots each release; add "Get it on Google Play" once v1.0 is live.
