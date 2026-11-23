# PillPaatha — Firebase setup (done separately, NOT by the build agent)

The app runs end-to-end WITHOUT Firebase: schedule generation falls
back to a clearly-labelled built-in sample. To switch on real Gemini
schedule generation (Firebase AI Logic) and the planned caregiver
sync, a human completes these steps:

1. Create a Firebase project named **PillPaatha** in the Firebase
   console (this is also the new Firebase project the hackathon plan
   calls for).
2. Register the Android app with package name
   `in.pillpaatha.pillpaatha` and download `google-services.json`.
   Place it at `android/app/google-services.json` (replacing nothing —
   no such file is committed on purpose).
   For iOS, register bundle id `in.pillpaatha.pillpaatha` and place
   `GoogleService-Info.plist` in `ios/Runner/`.
3. In the Firebase console, enable **AI Logic** (Gemini API) for the
   project, and enable **App Check** (mandatory per #BuildHybridAI
   rules) with Play Integrity / App Attest.
4. Later (caregiver sync step): enable **Authentication** and
   **Cloud Firestore**; the app's `ScheduleRepository` interface in
   `lib/data/app_store.dart` is the seam where the Firestore
   implementation slots in.
5. Rebuild via the GitHub Actions cloud route (local Gradle builds
   are not viable on the build VM). No code changes are needed: the
   app detects a successful `Firebase.initializeApp()` at startup and
   switches from the sample generator to Gemini automatically.
