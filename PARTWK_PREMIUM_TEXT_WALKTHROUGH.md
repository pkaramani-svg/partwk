# Local Premium chapter-text repair

## Isolated workflow continuation — 4 November 2026

**Account-scoped streak follow-up, 5 November 2026:** Daily completed-keypoint, completed-book and popup-shown keys now include the account UID; the in-memory learning-time counter is also per account. Existing unowned keys are left untouched and ignored because their owner cannot be established. Consequently, an unowned same-day local count is not carried over; existing server-side streak and achievement records are not migrated or changed by this local work. Thresholds and reward logic are unchanged.

The local widget test passed for primary → family → signed out → primary, including independent popup markers and ignored legacy keys. The Android emulator test passed against synthetic Firebase records: 40 learning seconds on one account did not combine with 40 on the other, the primary's own counter resumed on return, each account reached its existing streak milestone and retained one copy of the achievement after repeated events. An earlier test expected a streak of 3 but got 1 because the Android emulator's clock was weeks behind the host; the fixture was corrected to use the device's UTC date, without changing either clock. Targeted analysis passed with informational notices. Physical-phone airplane-mode and offline-audio playback are still manual checks.

**Account-switch follow-up:** A deterministic Android-emulator reproduction captured `Null check operator used on a null value` at `FirebaseAuthService.checkAndUnlockAchievements` after its `await AppLocator.db.fetchBooks()`, called by `updateListeningProgress`. Sign-out had cleared `_currentUser` during that await. The full pre-fix diagnostic is in the local, ignored `/private/tmp/partwk-switch-repro.log`; no real user or credential was used. The achievement check now verifies the original account after the await. Player saves are tied to the playback owner, sign-out clears/stops the player before the account changes, delayed playlist work is guarded, and player stream subscriptions are cancelled when the service is disposed. Relevant failures now include a stack in diagnostics.

The final Android integration test `integration_test/account_switch_repro_test.dart` passed against the demo emulators. It forced the original paused-fetch/sign-out race, switched from primary playback to family playback and then signed out, verified the player cleared, and checked the separate Firestore progress records for both accounts. It also asserted that no listening-progress or audio-state save error was logged. Targeted Flutter analysis completed with no errors; the existing completion/offline support tests passed 11 tests. The earlier offline reopening check used simulated offline status: actual airplane-mode and offline-audio playback remain unverified.

The former shared streak preference keys remain on the device but are not read into the account-scoped counters, as described in the streak follow-up above.

**Earlier workflow and profile follow-up:** The Android integration test passed on the local demo emulators: free, primary and family reading; primary and family progress persisted to the server while protected profile fields stayed unchanged; the completion popup was dismissed through **Continue**; the audio text panel displayed its fixture text; and the encrypted download reopened while the app's network check was set to offline. This simulates offline status; it is not an airplane-mode test, an offline-audio playback test, or a timing/highlighting verification. The separate null-check reported by that run was subsequently reproduced and addressed as described above. A targeted analyzer run completed with no errors and 14 informational notices.

The former Firestore permission denial came from `_updateUserDocument` merging `UserModel.toMap()` into `/users/{uid}`. That included `subscriptionStartDate` and `subscriptionExpiryDate` (missing from the fixture's stored profile), as well as `subscriptionStatus`, `hasFamilyPremium` and `familyMembers`. The progress write now excludes those backend-controlled fields while retaining the personal fields. Local rules now use changed-field checks, blocking addition, modification and deletion of protected fields, and permit new accounts only empty/null legacy family and subscription fields. The actual Firestore emulator test `scratch/profile_progress_rules_test.js` reproduced the old denial and passed personal progress, registration and protected-field tampering checks. These local rules have not been deployed.

The isolated Android Firebase values are inserted only when `PARTWK_ISOLATED_TEST=1`; otherwise Gradle applies the existing Google services configuration. The app additionally requires the demo project and emulator flag, refuses emulator mode outside debug, and checks all four emulator ports at startup. This is source/configuration inspection and an actual debug-emulator run; a production release build was not run.

**Earlier reader follow-up:** The primary-reader failure was caused by the isolated Android build's synthetic Firebase API key having an invalid format. Android's Firebase Installations SDK rejected it before the protected-text callable ran; the reader was visible and the synthetic primary was signed in. The isolated build now uses a syntactically valid dummy key for the same demo project. Normal debug/release configuration and reader code were not changed. Subsequent results are in the latest follow-up above.

**Product policy:** every published book whose `isPremium` checkbox is unticked is fully free; there may be multiple free books. Books with the checkbox ticked require valid Premium or family access. Publication is independent: an unpublished language remains protected for both free and Premium books. There is no single-sample limit or new sample classification in this repair.

An additional run of `scratch/multiple_free_books_emulator_test.js` passed against the actual local Firestore rules: two distinct free books were readable by free and unauthenticated SDK callers and via unauthenticated REST; hidden free-language documents and private paid text were denied. The earlier primary/family callable checks remain the evidence for paid access. This does not resolve the outstanding Android reader test failure described below.

This section supersedes the older status notes below. No production data or deployment was changed. The emulator-only Android build uses application ID `com.pkgames.partwk.emutest`, a `demo-partwk-text` Firebase configuration and explicit loopback Auth, Firestore, Functions and Storage endpoints. It refuses to start if its demo configuration, debug flag or any of the four endpoints is missing. Push notifications, purchase checkout, external sign-in and external REST fallback are disabled for this test build. Production release settings and audio delivery are unchanged.

The synthetic Flutter Android app reached the local fixture catalogue; [this Android emulator screenshot](scratch/partwk-workflow-runtime.png) shows the synthetic primary account and local catalogue. The latest Android run is described above. The earlier trending-books query permission warning remains to be investigated. Test entitlements are synthetic and do not verify billing.

The Firestore/Auth/Functions emulator suite `scratch/premium_text_emulator_test.js` passed: free SDK reads; Premium private-text and hidden-language denial through SDK and both unauthenticated and Firebase-token REST; trusted primary/family callable retrieval; unauthorized publishing and absent-language failures; publishing and retrying one language; preserving two categories and another language; changing a draft without changing the published text, then republishing; selected-language quiz/flashcard publishing; and restoring then hiding a free-book language. These are actual backend operations and rules, not admin browser interaction. No browser surface was available to exercise the admin interface itself.

The migration dry-run against five local fixture books reported four already migrated and one publishing fixture containing English and Arabic. Earlier in the same isolated suite dry-run and apply migrated synthetic free-hidden and Premium records and a repeated run confirmed their migration version. This does not identify all real-data conflicts, missing study records or old-client compatibility. The migration script explicitly refuses production projects and needs a separately reviewed production-capable implementation.

`flutter test --no-pub test/completion_support_test.dart test/offline_support_test.dart` passed 11 tests. The isolated Android APK and `npm run build --prefix admin_panel` built successfully; the Android build reports existing Kotlin Gradle Plugin warnings for `cloud_functions` and `sign_in_with_apple`, and Vite reports existing chunk-size and dynamic-import warnings. Bulk publish and bulk unpublish remain unavailable: the client currently throws and asks an administrator to publish each selected language from its editor. Restoring safe bulk operations needs a backend operation with per-book language and draft semantics; it was not introduced without that validation.

### Run the isolated APK

APK: `build/app/outputs/flutter-apk/partwk-emulator-debug.apk`. These commands use only the local demo emulators. Start the emulator suite in one terminal from the repository root:

```sh
sh scratch/start_workflow_emulators.sh
```

With the suite running, seed and migrate its synthetic data in another terminal:

```sh
env -i PATH=/usr/local/bin:/usr/bin:/bin GCLOUD_PROJECT=demo-partwk-text FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:19099 FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:19199 node scratch/seed_workflow_emulator.js
env -i PATH=/usr/local/bin:/usr/bin:/bin GCLOUD_PROJECT=demo-partwk-text FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 node tools/premium_text_migration.js --apply
```

Connect an Android phone with USB debugging or start an Android emulator. Set `DEVICE` to its ID from `adb devices`, then forward all four services and launch the separate test app:

```sh
ADB=/Users/peshrawkaramani/Library/Android/sdk/platform-tools/adb
DEVICE=R3CR406043J
$ADB -s "$DEVICE" reverse tcp:19099 tcp:19099
$ADB -s "$DEVICE" reverse tcp:18080 tcp:18080
$ADB -s "$DEVICE" reverse tcp:5001 tcp:5001
$ADB -s "$DEVICE" reverse tcp:19199 tcp:19199
$ADB -s "$DEVICE" install -r build/app/outputs/flutter-apk/partwk-emulator-debug.apk
$ADB -s "$DEVICE" shell am start -n com.pkgames.partwk.emutest/com.pkgames.partwk.MainActivity
```

Synthetic accounts are `free@test.invalid`, `primary@test.invalid` and `family@test.invalid`, password `Test-only-123!`. They and their audio exist only in the emulator. The `operator@test.invalid` fixture is an emulator-only admin. The admin dev server can be started with `VITE_PARTWK_EMULATOR=true npm run dev --prefix admin_panel -- --host 127.0.0.1`; browser UI operation remains unverified. Emulator fixture data is temporary.

For an actual airplane-mode check, first start the app with the emulators and USB reverse routes active, sign in, and download the synthetic book. Keep the app running, enable airplane mode on the phone and ensure Wi-Fi is off, then remove the four USB routes with `$ADB -s "$DEVICE" reverse --remove tcp:19099`, and likewise for `18080`, `5001` and `19199`. Open the downloaded text and play downloaded audio. Restore the four `reverse` commands before returning online. The isolated build requires reachable emulators at startup, so a cold start after removing the routes is expected to show its fail-closed configuration screen; it is not a valid cold-start offline test of the normal release build.

Phone checklist (not yet passed): read and play the free fixture; read Premium as primary and family; test audio text, seeking and progress; download, disconnect and reopen; exercise selected-language publish, hide and restore from the admin UI.

### Coordinated rollout — not executed

1. Investigate the earlier trending-query permission warning; complete admin browser and real-phone account-switch, streak, audio/offline tests. Finish billing verification separately; do not mistake synthetic entitlements for paid access.
2. Inventory and back up existing books, hidden languages, study data and legacy clients; develop and review a production-capable migration with collision and rollback handling. The included emulator-only tool cannot perform this step.
3. In staging, deploy reviewed callable/rules and indexes, run a migration rehearsal against representative copied data, test publishing and compatible mobile/admin versions, and resolve legacy-client access. Establish a rollback and content freeze for cutover.
4. After explicit production approval, make compatible backend and clients available in a coordinated window, stop old writers, back up and migrate content, verify counts and access, then enforce reviewed rules and reopen publishing. Verify monitoring and rollback before resuming. This ordering must be adapted to the chosen old-client transition; old clients need public text and cannot be assumed compatible.

The earlier notes below describe earlier stages and should not be read as the current test-build status.

## Current continuation: selected-language publisher

The admin editor now loads content through the administrator-only `getBookForEditing` callable, saves changes to a draft, and calls `publishBookLanguage` for the selected language. The callable checks authorization and commits public book metadata, private Premium text, and that language's draft quiz/flashcards in one Firestore transaction. It preserves the book's existing classification and categories and leaves other languages and the draft unchanged. `setBookLanguageVisibility` moves a language's full content out of or back into its public book document atomically. The emulator-only migration now handles hidden free-language chapters as well as Premium text. Regeneration stays in drafts.

The local emulator fixture has exercised an unauthorized publish, failed publication of an absent language, repeat publication, publication of a second language without losing the first, protected SDK/REST reads, primary/family retrieval, free-language hide/restore, and selected-language quiz/flashcard publication. All data used was synthetic and local. Existing Flutter tests passed 12/12; the admin production build and local Android debug build passed. The builds reported existing Vite chunk/dynamic-import notices and Flutter plugin Kotlin Gradle warnings.

**Remaining blockers:** this is not a production-ready rollout. Bulk publication/unpublication is temporarily disabled to prevent publishing every draft language or overwriting a staged draft. Direct privileged Firestore writes can still bypass the callable; old clients and existing public data require a reviewed migration and coordinated rollout. Existing study records and publication transitions need a full migration audit; the local script is intentionally emulator-only. The admin UI and reader/audio/offline workflows have not been verified on a device. The new backend's study queries may require Firestore composite indexes in staging. The debug APK uses the configured production Firebase project by default; emulator routing covers only selected Firebase services and the public REST fallback can still contact production.

APK: `build/app/outputs/flutter-apk/app-debug.apk`. If installed on an Android device, this exact command launches the **production-configured** debug app: `/Users/peshrawkaramani/Library/Android/sdk/platform-tools/adb shell am start -n com.pkgames.partwk/.MainActivity`. Do not use that configuration for isolated test fixtures. An emulator-only launch is not yet verified because all external routes are not isolated.

Phone checklist after complete isolation: publish one language and confirm another remains private; read and resume audio with synchronized text; test highlights/progress; download and reopen offline; repeat with free, primary and family test accounts and expired access.

The confirmed DeepSeek key assignment was removed from `.zshrc` without a backup; a new login shell with the inherited variable removed reported it absent. The retained DeepSeek-named alias was not a credential. The checked local Firebase debug and task logs were scanned privately against the inherited key value without printing it; none currently contained that value, so no files required redaction. The earlier agent tool transcript did contain the value and cannot be erased by this change. In an already-running terminal, use `unset DEEPSEEK_API_KEY`; restart the IDE to clear inherited environment variables from its existing processes. No Gemini configuration was changed.

The existing `isPremium` classification is unchanged. Free books retain their original content; the local emulator migration moves Premium chapter `content` and audio-synchronisation segment `text` into `premiumBookText/{bookId}` while retaining public catalogue and audio fields. Audio delivery and production data were not changed.

`getPremiumChapterText` checks the requested published book, hidden language, active entitlement, and (for family access) the current primary entitlement and both relationship records. Firestore rules deny all direct client reads of the private collection. The reader merges the callable response into the chapter structure when streaming.

The migration tool requires a loopback Firestore emulator and a `demo-*` project, defaults to dry run, applies only with `--apply`, and refuses to overwrite an existing private text document. It must not be used against production. A production migration implementation, backup and rollout review remain necessary.

## Executed checks

On 4 November 2026 the Auth, Firestore and Functions emulators ran `scratch/premium_text_emulator_test.js` against isolated `demo-partwk-text` fixtures. Dry-run and emulator-only apply each processed one Premium book. The tests passed for free-book SDK reading; absence of Premium chapter and segment text in public SDK/REST results; denied direct private-text and draft reads through the SDK and both unauthenticated and Firebase-token REST; denial of a free user's callable request; successful primary and family callable requests; and callable denial of the fixture's hidden Premium language and draft.

`flutter analyze --no-pub lib/features/book/summary_reader_screen.dart` found no errors but exited 1 with 26 existing warnings/information notices. The existing Flutter suite passed 12 tests after the segment-hydration adjustment. No phone tests or Android build for this adjustment were performed.

## Important incomplete compatibility work

This local change is **not ready for rollout**. The existing admin publisher can still put Premium text in public book documents. Other book fields (including summary, ideas and quotes) may contain protected text and are not migrated by this chapter-only repair. Hidden languages on non-Premium books have not been migrated or independently verified, so the test above proves only the Premium fixture's hidden language and the draft. The audio player reads segment text directly from its supplied public chapter data, and the downloader saves the book object it is given; those paths have not yet been updated to hydrate private text. Existing readers and offline downloads must be tested against migrated books. Do not enforce or deploy this change until those paths and publishing are coordinated.

For a future rollout, complete and verify all readers, downloads, admin publishing and migration coverage first; then test migration and the new app against staging; release a compatible client and only then migrate data and deploy the reviewed callable and rules in a coordinated window. Old clients depend on public text and need an explicit compatibility plan.

## Continuation: 4 November 2026

`ProtectedTextService` now hydrates Premium chapters, paragraph timing text and the five localized full-content fields for the online reader, online playback launched from Book Details and the encrypted offline download path. It does not change audio URLs. The emulator migration now moves the five full-content fields as well, preserves public descriptions, and upgrades the earlier version-1 private record without replacing its chapter text. Existing free/Premium classifications remain unchanged.

Regeneration is now directed to `books_draft`, `quizzes_draft` and `flashcards_draft` instead of writing regenerated text to public collections. The admin panel temporarily refuses Premium publication via its old client path. This is a **stopgap**, not the requested finished manual publication flow: a trusted atomic publisher and the ability to publish the new draft study material are still missing. Direct privileged writes are not prevented by a client-side guard. Free-book hidden-language content and existing quiz/flashcard records are still exposed by existing rules. The audio text panel reached via other navigation paths and offline revalidation require device-level testing.

Checks executed: `python3 -m py_compile dynamic_summary_pipeline.py` passed; targeted Flutter analysis of the download, details and service files reported no errors (41 informational notices, with warnings/info nonfatal); the Flutter suite passed 12 tests; `npm run build --prefix admin_panel` passed with the existing Vite chunk/dynamic-import warnings; and an Android debug APK was built at `build/app/outputs/flutter-apk/app-debug.apk`. Flutter warned that two plugins still apply the Kotlin Gradle Plugin. These checks do not establish reading, audio sync or downloads on a phone.

The isolated emulator fixture passed SDK/REST free/Premium checks and tested private chapter, segment, summary and key-idea fields, a hidden Premium language, and a draft. Regeneration, republishing, hidden free languages, quiz/flashcard protections and real-device offline behaviour have **not** passed end-to-end tests. No production migration or deployment was performed.

### Credential and log handling

Firebase CLI debug output previously included an inherited DeepSeek API key. The credential value appeared in agent tool output/transcript; it was not intentionally placed in a report. `firebase-debug.log` and other Firebase logs are ignored by Git. `scratch/run_premium_text_emulator.sh` uses an explicit minimal environment with no inherited API key or debug flag; use it for this fixture rather than starting the CLI with the full shell environment. The earlier transcript cannot be retracted by this workspace change. The credential owner should assess that exposure and rotate that specific key if appropriate.

### Rollout is blocked

Before any coordinated staging/production rollout: implement and test the trusted admin publishing/unpublishing path, publication-aware free-language storage, private quiz/flashcard access and migration, and compatibility for all reader/audio/download entry points. Review a production-capable migration separately; the included script intentionally rejects non-emulator targets. Test the complete new client against migrated staging data, establish an old-client transition, then obtain approval for the coordinated migration and deployment.

### Audio-player continuation

The audio-player screen now independently loads Premium text from a valid offline download or the trusted text callable, including when opened from Home. Audio URLs and playback position are not modified. This code has not been validated on a physical device; text synchronization, playback resume and offline behavior remain on the phone-test checklist.

The previously exposed DeepSeek key was identified by environment-variable name in the user's shell startup configuration (`.zshrc`). The earlier Firebase CLI debug output entered the agent tool transcript; local Firebase debug logs are ignored by Git. The emulator test wrapper uses a minimal environment without that key. No credential was rotated or copied into this report.

Continuation checks: the existing Flutter suite passed 12 tests; targeted audio-screen analysis reported no errors, one warning and 11 informational notices with nonfatal warning/info flags; and the existing isolated emulator fixture passed again. These tests do not cover secure admin publication, hidden free-language access, quizzes/flashcards, or playback/offline runtime. An Android device and emulator were detected, but neither was launched against the app because the ordinary debug configuration may access the configured Firebase project. Before phone testing, isolate every backend and external fallback, then check Home resume, Book Details playback, synchronized text, reading highlights/progress, and offline use/expiry for both free and Premium fixtures.

Later continuation: local Firestore rules now check book publication, language visibility and effective Premium/family entitlement for quiz and flashcard reads. The emulator test passed for direct SDK reads of free, paid and hidden fixtures, filtered app-style quiz queries, and a denied unauthenticated/ordinary-token REST request for paid quiz data. This does not yet verify every study-material operation or publishing/regeneration path; rules have not been deployed. An Android debug build completed after the audio-player change. The secure admin publisher, protection of hidden free-language text in public book documents and end-to-end runtime verification remain incomplete.
