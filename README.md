# PillPaatha 💊

**A medicine companion for elderly parents — and the family who cares for them.**

Take a photo of a medicine strip or a doctor's prescription. PillPaatha reads
it on the phone itself, then turns it into a simple dosage schedule in
**Tamil and English**, with gentle reminders and a caregiver view so a son or
daughter at work can see that Amma's morning tablet was taken on time.

Built for the **#BuildHybridAI 2026** hackathon (Google × Firebase).

> ⚕️ **This app does not replace your doctor.**
> இந்த செயலி உங்கள் மருத்துவருக்கு மாற்றாகாது.
> PillPaatha never diagnoses and never advises a dose beyond what the
> prescription itself says. This safety line is shown on every screen.

## The problem

Elderly patients in India often juggle 4–8 medicines with English-only labels
and handwritten prescriptions. Wrong medicine, wrong dose, wrong time — and
family members have no way to check in without a phone call. Look-alike
medicine names (Metformin / Metoprolol) make it worse.

## Hybrid AI design

PillPaatha is deliberately **hybrid** — each half does what it is best at:

| Layer | Where it runs | What it does |
|---|---|---|
| **OCR** | On-device (ML Kit) | Reads strip / prescription text offline. Private, instant, works without a network. |
| **Understanding** | Cloud — Gemini via Firebase AI Logic | Structures the read text into a schedule (medicine, dose, timing, food relation), explains each medicine in plain Tamil + English, and flags look-alike names to double-check. |
| **Reminders & records** | On-device | Daily dose notifications with Taken / Skip actions; every status is recorded locally. |
| **Family sync (seam ready)** | Firebase | Schedules sit behind a repository interface so Firestore caregiver sync slots in without screen changes. |

The Gemini prompt is fenced: it may only restate what the prescription text
says — inventing a dose, a fact, or a diagnosis is explicitly forbidden, and a
deterministic local check backstops the look-alike warnings.

**Honest fallback:** if Firebase is not configured, the app still runs
end-to-end on a built-in sample schedule — always shown under a clear
**SAMPLE** banner, never dressed up as real output.

## Features

- 📷 Photo → on-device OCR → fully editable medicine list
- 🗓️ Gemini-generated daily schedule in Tamil + English, grouped by day-part
- ⏰ Daily reminders with **Taken / Skip** right on the notification
- 👀 Caregiver view: today's Taken / Missed / Skipped / Upcoming at a glance
- ⚠️ Look-alike medicine caution flags
- 👵 Elderly-first design: warm peach `#FFF6EF`, deep violet `#5B4B8A` and
  amber `#E8A33D`; large 16–18px type, big tap targets, bilingual labels

## Build

```sh
flutter pub get
flutter analyze   # clean
flutter test      # 8/8
```

Firebase is configured per [`FIREBASE-SETUP.md`](FIREBASE-SETUP.md)
(project `pillpaatha`, Android package `in.pillpaatha.pillpaatha`).
Without it, the app runs in the labelled sample mode described above.

### CI build (GitHub Actions)

Release APKs are built by `.github/workflows/build-release.yml`
(workflow_dispatch, JDK 17 temurin, Flutter 3.47.8,
`flutter build apk --release --split-per-abi`).

`google-services.json` is **not** in this public repo. The workflow restores
it from an Actions secret:

1. Base64-encode your file: `base64 -w0 android/app/google-services.json`
2. Save the output as a repository Actions secret named
   **`GOOGLE_SERVICES_JSON`**
3. Run the workflow — it decodes the secret to
   `android/app/google-services.json` before building.

CI builds are keyless (debug-signed); release signing is applied locally
afterwards, so no signing key ever enters the repo or CI.

## Tech

Flutter 3.47.8 · Dart · `google_mlkit_text_recognition` · `firebase_core` ·
`firebase_ai` (Gemini 2.5 Flash) · `flutter_local_notifications`

## License

MIT — see [`LICENSE`](LICENSE). © Gunasekar E.
