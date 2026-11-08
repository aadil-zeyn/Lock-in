# Plan — Photo food logging ("snap to log")

Status: **proposal, not built**. Owner decision needed on the open questions at the end.

## Goal
On the Food tab, one tap opens the camera; after the photo, the app shows the food it
recognised with kcal, protein, carbs and fat already filled in, and one more tap logs it.
Manual entry, favourites and the catalog stay exactly as they are.

## Does this conflict with "no network calls"?
Partly. It breaks the project rule in `CLAUDE.md` ("No backend, no network calls"), but
not the PRD requirements behind that rule, as long as the feature is built like this:

| PRD requirement (v1.0 §Offline / §Privacy) | How this feature meets it |
|---|---|
| All MVP features work without internet | Photo logging is an **extra**, never the only way to log food. With no connection the button explains that and opens manual entry. |
| No mandatory authentication | No accounts. The app sends a random install ID and an app token; nothing to sign in to. |
| Don't send workout data to external services without explicit consent | **Off by default.** The first use shows a consent screen. Only the photo (re-encoded, EXIF/GPS stripped) and an optional text hint are sent. No workout, body or history data ever leaves the phone. |
| Keep fitness records on the device | Results are saved in the local Drift DB like any other entry. The backend keeps nothing. |

What actually changes:
- The **release** build gets the `INTERNET` permission. Today only the debug/profile
  manifests have it (`android/app/src/debug|profile/AndroidManifest.xml`), so the release
  APK cannot reach the network at all. This permission is the visible cost of the feature.
- `CLAUDE.md` rule becomes: *"No network calls, except the opt-in photo food analysis,
  which talks only to our own backend."* Add a matching PRD amendment (v1.2).

**Fully offline alternative (not recommended for v1):** an on-device food classifier
(TFLite, Food-101 style) can name a dish, but cannot judge the portion, so kcal would come
from a catalog lookup and be much less accurate. Keep it as a possible later fallback.

## Why a backend (FastAPI) instead of calling the AI API from the app
- An API key inside the APK can be extracted by anyone who has the file. The backend
  keeps the key server-side.
- One place for rate limits, a spend cap, image size checks and response validation.
- The model or prompt can change without shipping a new APK.

## Repo layout
Recommended: a **separate repo** (e.g. `aadil-zeyn/lock-in-api`).
- Different language, tooling and deploy cycle from the Flutter app.
- Keeps `.github/workflows/android-release.yml` from cutting app releases for backend-only pushes.
- Once you create it, add it to the session and I'll scaffold it.

(Alternative: a `backend/` folder here, with the release workflow's `paths` filter
updated to ignore it.)

## Architecture
```
Food tab ─tap─▶ camera (image_picker, already a dependency)
   │ resize ≤1024 px, JPEG q≈80, re-encode (drops EXIF/GPS)   ~100–200 KB
   ▼
POST https://<api>/v1/food/analyze   (multipart: image, meal?, hint?)
   │ headers: Authorization: Bearer <app token>, X-Install-Id: <uuid>
   ▼
FastAPI ─▶ Claude vision (structured JSON output) ─▶ validate/clamp ─▶ JSON
   ▼
Review card (prefilled food_entry_sheet) ─tap "Log"─▶ FoodEntries (Drift)
```

### API contract (v1)
`POST /v1/food/analyze` → `200`
```json
{
  "items": [
    {"name": "Chicken biryani", "portion": "1 plate (~350 g)", "grams": 350,
     "kcal": 610, "protein_g": 28, "carbs_g": 78, "fat_g": 20}
  ],
  "total": {"kcal": 610, "protein_g": 28, "carbs_g": 78, "fat_g": 20},
  "confidence": "medium",
  "note": "Portion estimated from plate size."
}
```
Errors: `422 not_food` (no food in the photo), `413` image too large, `429` rate limited,
`503` model unavailable. The app shows a short message and offers manual entry for each.

`GET /health` for uptime checks.

## Backend (new repo)
- Python 3.12, FastAPI, Uvicorn, official `anthropic` SDK, Pydantic models for the
  response schema (sent as the structured-output format, so the reply is always valid JSON).
- Model: `claude-opus-5-5` by default, with low effort to keep latency down, and the
  server-side refusal fallback enabled. Rough cost: a 1024 px photo is about 1–1.5k input
  tokens plus a short JSON reply, about $0.01 per photo. A cheaper model is a one-line
  config change if you'd rather trade some accuracy for cost.
- Prompt: identify each item, estimate the portion in grams, compute macros, say how
  confident it is; reply `not_food` when there is no food. Optional user hint
  ("2 rotis, no ghee") is added as text.
- Validation: kcal 0–5000 per item, macros ≥ 0, kcal roughly consistent with
  4/4/9 × macros (flag, don't reject).
- Abuse/cost control: app token + per-install rate limit (e.g. 30/day), max upload 2 MB,
  monthly spend limit set in the Anthropic console.
- Privacy: images held in memory only; request bodies never logged.
- Config via env vars: `ANTHROPIC_API_KEY`, `APP_TOKEN`, `RATE_LIMIT_PER_DAY`, `MODEL`.
- Dockerfile; deploy to any small container host (Cloud Run, Fly.io or Render free tier).
  CORS allowlist for the web build's origin if the web app should use it too.
- Tests: pytest with the Claude client mocked (happy path, not-food, oversized image,
  bad token, rate limit, out-of-range values clamped).
- Small eval: ~30 labelled food photos (your usual meals) to measure kcal error before
  and after prompt changes.

## App changes (this repo)
1. **Settings + consent** — "Photo food logging" toggle (off by default) and a one-time
   consent sheet explaining what is sent and where. Stored in the existing settings table.
2. **Network** — add `INTERNET` to `android/app/src/main/AndroidManifest.xml`; add the
   `http` package; backend URL and app token injected with `--dart-define`
   (CI secrets `FOOD_API_URL`, `FOOD_API_TOKEN`), so nothing is hard-coded.
3. **Data layer** — `lib/features/food/data/food_photo_service.dart`: compress, upload,
   parse into a `FoodPhotoResult`; typed errors (offline, not food, rate limited, server).
4. **UI** — camera button on the Food tab (accent colour, `IconBadge`), loading state
   with a cancel option, review card listing items with kcal/macros, editable before
   saving; multi-item photos log as one entry by default with "split into items" as an
   option. Meal is preselected from the time of day. "Save as favourite" reuses `SavedFoods`.
5. **Schema v5 → v6** — add `FoodEntries.source` (`manual` | `photo`, default `manual`)
   so photo entries can be shown with a small camera icon (icon + label, not colour
   alone) and accuracy can be reviewed later. Follow the data rules: bump
   `schemaVersion`, `onUpgrade` step, schema dump, extend `test/migration_test.dart`.
   Photos are **not** stored by default.
6. **Tests** — service with a fake HTTP client (each error path), widget test for the
   review card, migration test.
7. **Docs** — update `CLAUDE.md` (network rule, schema version — the file still says
   v3 while the code is at v5), `docs/ROADMAP.md`, PRD v1.2 amendment, and a privacy
   note on the showcase page.

## Phases
| Phase | Scope | Result |
|---|---|---|
| 0 | Decide open questions, PRD amendment, create backend repo | Agreed rules |
| 1 | Backend MVP + deploy + eval set | Working `/v1/food/analyze` URL |
| 2 | App MVP: toggle, consent, camera → review → log, schema v6 | Usable on the phone via Obtainium |
| 3 | Offline queue (keep the photo, analyse when back online), split items, portion slider, HC nutrition sync | Polished |

## Open questions (with my recommendation)
1. **One tap or confirm?** Photo kcal estimates are often off by 20–30 %.
   Recommend: snap → review card → "Log" (two taps), plus an optional "auto-log with
   undo" setting for true one-tap.
2. **Model / cost** — Opus 5.5 (best accuracy, about $0.01/photo) vs a cheaper model.
   Recommend: start with the default, measure on the eval set, then decide.
3. **Hosting** — Cloud Run / Fly.io / Render. Recommend whichever you already have an
   account on; all fit in a free tier at personal-use volume.
4. **Web app** — enable photo logging on the web build too, or Android only for v1?
   Recommend Android only first.
