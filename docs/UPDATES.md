# Getting updates on the phone without a cable

Every push to `main` that touches the app runs **GitHub Actions**
(`.github/workflows/android-release.yml`): analyze → test → build a signed
APK → publish it as a **GitHub Release** (`v0.<run>.0`). The phone installs
releases with **Obtainium**. Lock-in itself makes no network calls.

## One-time: add the signing key to GitHub

Updates only install over the existing app when they are signed with the
**same key** as the installed app — otherwise Android asks to uninstall,
which deletes the app's data. The app is currently signed with this PC's
Android debug key (`%USERPROFILE%\.android\debug.keystore`).

In the repo on GitHub: **Settings → Secrets and variables → Actions → New
repository secret**, and add:

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | the keystore file as base64 (one long line) |
| `KEYSTORE_PASSWORD` | `android` |
| `KEY_ALIAS` | `androiddebugkey` |
| `KEY_PASSWORD` | `android` |

Then run the workflow once: **Actions → Android release → Run workflow**.

> The debug key is fine for installing on your own phone. Before a Play
> Store release, create a proper upload key and switch (that needs one
> backup → reinstall → restore).

## One-time: Obtainium on the phone

1. Install Obtainium from its GitHub releases
   (github.com/ImranR98/Obtainium → Releases → the `arm64-v8a` APK) or from
   F-Droid / IzzyOnDroid.
2. In Obtainium tap **Add app** and paste
   `https://github.com/aadil-zeyn/Lock-in`.
3. Tap **Install** the first time. After that Obtainium checks for new
   releases in the background and notifies you; tap **Update**.

## Local builds

Local `flutter build apk` keeps using the debug key (no `android/key.properties`
on the PC), so locally built and CI-built APKs can replace each other.
