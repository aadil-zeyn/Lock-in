# Lock-in — Phase 1 starter

Foundation for the Lock-in Flutter app: dark theme + design tokens, 5-tab navigation,
reusable components, and a Drift (SQLite) database with the full schema and a
50-exercise seed library. The dashboard and exercise library already read from the
database; everything else shows designed empty states.

```
docs/   PRD v1.0 (your draft) + v1.1 change notes
lib/    app source (copy into your Flutter project)
test/   unit tests for strength/unit maths
```

## 1. One-time setup on Windows 11

1. **Turn on Developer Mode** — Settings → System → For developers → Developer Mode.
   Flutter needs it to symlink Android plugins on Windows.
2. **Install Flutter** — in VS Code install the *Flutter* extension, press
   `Ctrl+Shift+P` → **Flutter: New Project**, and when it says the SDK is missing choose
   **Download SDK** (pick e.g. `C:\dev`). Let it add Flutter to your PATH. Restart VS Code.
   (Avoid paths with spaces, and don't put the SDK in `C:\Program Files`.)
3. **Android pieces** — open Android Studio → *More Actions* → **SDK Manager** →
   *SDK Tools* tab → tick **Android SDK Command-line Tools (latest)** → Apply.
4. In a terminal (PowerShell):
   ```powershell
   flutter doctor --android-licenses   # press y to all
   flutter doctor                      # Windows/Chrome warnings are fine; Android must be ✓
   ```
5. **Device** — either a phone with *USB debugging* on (Developer options), or in
   Android Studio → **Device Manager** → create a Pixel emulator.

## 2. Create the project and drop in this code

```powershell
cd C:\dev
flutter create --org com.yourname --platforms android lock_in
cd lock_in

flutter pub add flutter_riverpod go_router drift drift_flutter
flutter pub add dev:drift_dev dev:build_runner
```

Now:
- Delete the generated `lib\` folder and `test\widget_test.dart`.
- Copy this starter's `lib\`, `test\` and `docs\` into `C:\dev\lock_in\`.

Generate the database code (creates `app_database.g.dart`):

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Run it:

```powershell
flutter run
```

Or open the folder in VS Code and press **F5**.

Optional: change the launcher name in `android\app\src\main\AndroidManifest.xml`
from `android:label="lock_in"` to `android:label="Lock-in"`.

## 3. Daily workflow

- Changed a table in `app_database.dart`? Re-run build_runner (or keep
  `dart run build_runner watch --delete-conflicting-outputs` running).
- Tests: `flutter test`
- Lints: `flutter analyze`

## 4. Troubleshooting

| Problem | Fix |
|---|---|
| `Building with plugins requires symlink support` | Developer Mode (step 1). |
| Gradle error mentioning **NDK version** | Open `android\app\build.gradle.kts`, set the `ndkVersion` it asks for (e.g. `ndkVersion = "27.0.12077973"`). |
| `Target of URI hasn't been generated: app_database.g.dart` | Run the build_runner command. |
| Errors after pub upgrades | `flutter clean`, `flutter pub get`, rerun build_runner. |
| Changed the schema and the app crashes on launch | During Phase 1 just uninstall the app from the device (wipes the DB). From release onward, bump `schemaVersion` and write a migration. |

## 5. What's in Phase 1

- **Theme** — `lib/app/theme/`: colours, spacing, radii, number styles (tabular figures).
- **Navigation** — `lib/app/router.dart`: GoRouter `StatefulShellRoute`, each tab keeps its state.
- **Components** — `lib/core/widgets/`: `AppCard`, `PrimaryButton`, `SecondaryButton`,
  `StatCard`, `EmptyState`, `SectionHeader`, `TabPage`.
- **Database** — `lib/core/database/`: all PRD tables with the v1.1 changes
  (name snapshots, archived exercises, kg canonical storage, set types, one-active-workout index).
- **Dashboard** — live from DB: active workout → "Resume", weekly dots, last workout, body weight.
- **Exercise library** — search + muscle filter over the seeded exercises (Workout tab → Exercise library).

Next up is Phase 2/3: custom exercise form, then the workout engine.
