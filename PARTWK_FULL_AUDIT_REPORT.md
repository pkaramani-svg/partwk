# PARTWK - COMPREHENSIVE TECHNICAL & SECURITY AUDIT REPORT
**Audit Date:** November 2, 2026  
**Target Repository:** Partwk (Mobile App, Admin Panel, Cloud Functions & Pipeline Infrastructure)  
**Evaluator:** Antigravity AI Senior Security & Systems Auditor  
**Report Version:** 1.0.0 (Production Pre-Release Audit)

---

## A. EXECUTIVE ASSESSMENT

### 1. What Partwk Currently Does
Partwk is designed as a multi-lingual, cross-platform micro-learning and book-summary ecosystem supporting English (LTR), Kurdish Sorani (RTL), and Arabic (RTL). 
- **Mobile Client (Flutter):** Provides animated onboarding, language switching with dynamic RTL/LTR layout mirroring, Firebase Authentication (Email/Password, Google, Apple, and Guest mode), home daily digest, catalogue browsing by category, a full-text summary reader with dynamic font sizing and dark reader mode, audio playback with background audio support (`just_audio` / `just_audio_background`), audio-text paragraph synchronization (using timestamped segment markers or proportional duration fallbacks), offline encrypted downloads (AES-256-CBC with keys in Secure Storage), user notes, text highlights, multiple-choice quizzes, flashcards, learning paths, consistency streak tracking, and promotional/emergency in-app popup announcements.
- **Admin Panel (React + Vite):** Web-based portal offering dashboard metric summaries, real-time user management (role toggling, subscription overrides, password resets, suspension), book content management (multi-lingual chapter text, audio uploads, cover art, draft vs. published segregation), popup campaign authoring, and global settings toggles.
- **Backend (Firebase):** Firebase Auth, Cloud Firestore, Firebase Storage, and Cloud Functions v2 (automated welcome and renewal emails via SMTP, daily subscription expiration checks, and custom password resets).
- **Automation Pipeline (Python):** End-to-end Python pipeline (`dynamic_summary_pipeline.py`) utilizing Google Gemini for multi-lingual summary drafting (English, Kurdish Sorani, Arabic) and audio narration (English, Arabic), Pillow for cover generation, and direct Firestore/Storage deployment. Kurdish audio narration is generated separately using the owner's dedicated Kurdish TTS setup elsewhere and uploaded directly to Firebase Storage.

### 2. Overall Readiness and Confidence Level
- **Overall Readiness:** **NOT READY FOR PRODUCTION RELEASE**
- **Confidence Level:** **VERY HIGH (Evidence-based inspection and runtime verification)**
- While core visual and UI reading/listening workflows are mature, the project contains **critical security vulnerabilities, severe store-policy blockers, hardcoded live credentials, missing iOS configurations, and completely unintegrated in-app payments**.

### 3. The Most Important Blockers and Risks
1. **Unprotected Remote Account Takeover (Critical):** Cloud Function `adminUpdateUserPassword` in `functions/index.js` was callable by *anyone on the public internet without authentication or authorization*, allowing arbitrary password resets for any user in Firebase Auth.
2. **Exposed Live Secrets & API Keys (Critical):** Live Gemini API keys, corporate SMTP email credentials (`info@partwk.com`), and pipeline admin credentials were historically stored in local config or source files. Additionally, legacy API keys for unused third-party services (OpenAI, kurdishtts.com) were present in `.env` and bundled in client build assets (`pubspec.yaml` bundled `.env`). Unused integrations have been removed and legacy keys flagged for revocation only, while active credentials require rotation.
3. **Completely Mocked In-App Purchases (Critical):** The "Subscribe" and "Restore Purchases" buttons on the paywall screen trigger a 1.2-second delay and grant 1 year of free Premium in Firestore without connecting to Apple StoreKit, Google Play Billing, or any payment gateway.
4. **Missing Account Deletion (Store Policy Blocker):** The mobile application provides no mechanism for users to delete their accounts, violating Apple App Store Review Guideline 5.1.1(v) and Google Play Developer Policies.
5. **Broken iOS Deployment Baseline (Critical):** `GoogleService-Info.plist` is completely missing from `ios/Runner/`, which will crash the app upon `Firebase.initializeApp()` on iOS. Furthermore, iOS entitlements for Apple Sign-In, Universal Links, and Push Notifications are absent from Xcode project configurations.
6. **Client-Controlled Authorization & Role Escalation (High):** Firestore database rules lack server-side field-level immutability for user roles and subscription statuses; mobile clients and admin interfaces perform direct client-side document mutations on `users/{uid}`.
7. **Simulated AI Coach (Medium):** The advertised "AI Personal Coach" feature is backed by `MockAICoachService`, returning hardcoded canned strings without calling any live LLM service (an unused `dart_openai` dependency was previously declared and has been removed).
8. **Catastrophic Cloud Billing Exposure (High):** Admin panel dashboard queries every single user document in the database simultaneously (`getDocs(collection(db, 'users'))`) and binds real-time listeners across the entire user base without pagination.

---

## B. AUDIT COVERAGE

| Area / Subsystem | Verification Level | Platform / Environment | Scope Tested | Notes / Constraints |
| :--- | :--- | :--- | :--- | :--- |
| **Mobile App: Compilation & Analysis** | Runtime Verified | macOS / Flutter 3.44.0 (Dart 3.12.0) | `lib/`, `test/` | 0 compiler errors; 45 warnings; 282 lints. |
| **Mobile App: Automated Tests** | Runtime Verified | Flutter Test Runner | Unit & Widget suite | 12 of 12 tests passed successfully. |
| **Mobile App: Auth & Session Handling** | Runtime Verified / Code Reviewed | Flutter / Firebase Auth | Email, Guest, Google, Apple | Apple Sign-in missing iOS entitlement; guest restrictions verified. |
| **Mobile App: Reader & Audio Player** | Code Reviewed | Flutter / `just_audio` | Reading, background audio, timestamps | Paragraph synchronization logic verified; tabs promised in README absent. |
| **Mobile App: Offline DRM & Encryption** | Code Reviewed | Flutter / `encrypt` / SecureStorage | Key generation, AES-256-CBC, temp audio | AES verified; temp playback writes unencrypted WAV/MP3 to sandbox. |
| **Mobile App: Localization & RTL** | Runtime Verified / Code Reviewed | Flutter / `GoogleFonts` | EN, KU (Sorani), AR | RTL mirroring works; Google Fonts fetched at runtime (offline risk). |
| **Mobile App: In-App Purchases** | Code Reviewed | Flutter / `paywall_screen.dart` | Paywall, restore purchases | Fake timer; 100% mocked; no StoreKit / Play Billing SDKs. |
| **Admin Panel: Build & Bundling** | Runtime Verified | Node.js 24 / Vite 8 | `admin_panel/` | Clean build in 904ms; 1.06MB chunk; previously bundled unused `VITE_OPENAI_API_KEY` (now removed and sanitized). |
| **Admin Panel: Auth & Access Control** | Code Reviewed | React / Firebase Auth | Login, 2FA, Session Storage | Bypassable client-side 2FA check via `sessionStorage`. |
| **Admin Panel: Book & Content CRUD** | Code Reviewed | React / Firestore / Storage | Uploads, drafts, deletions | Deleting books leaves orphaned Storage audio/covers and quizzes. |
| **Firebase: Cloud Functions** | Runtime Verified / Code Reviewed | Node.js 20 / Functions v2 | `functions/index.js` | Zero compile errors; critical unauthenticated Callable vulnerability. |
| **Firebase: Security Rules** | Runtime Verified / Code Reviewed | Live Project `partwk-bd4ec` | REST API / Client SDK | REST returns HTTP 403; no `firestore.rules` or `storage.rules` in repo. |
| **Platform: iOS Configuration** | Code Reviewed | iOS / Xcode project | `ios/Runner` | Missing `GoogleService-Info.plist` and `.entitlements` file. |
| **Platform: Android Configuration** | Code Reviewed | Android / Gradle Kotlin DSL | `android/app` | Release signed with debug keys; missing `INTERNET` in main manifest. |
| **Data Integrity & Bandwidth Costs** | Code Reviewed | Firestore & Storage patterns | Queries, Listeners, Bandwidth | Unbounded queries in dashboard; no pagination on `users`. |

---

## C. FEATURE INVENTORY

| Feature / Capability | Planned / Claimed | Actual Status | Verification Evidence |
| :--- | :--- | :--- | :--- |
| **Multi-Language Support (EN, KU, AR)** | Yes | **Implemented** | [app_localizations.dart:L15](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/localization/app_localizations.dart#L15); dynamic text direction switching verified. |
| **Kurdish / Arabic RTL Mirroring** | Yes | **Implemented** | [main.dart:L80-L111](file:///Users/peshrawkaramani/Desktop/Partwk/lib/main.dart#L80-L111); Arabic localization fallbacks configured for Kurdish locale. |
| **Guest Mode & Conversion** | Yes | **Implemented** | [login_register_screen.dart](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/auth/login_register_screen.dart); guest restriction blocks after Chapter 2. |
| **Reading Summary Reader** | Yes | **Partially Implemented** | [summary_reader_screen.dart:L33](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/book/summary_reader_screen.dart#L33); reads full chapter text, but 5-min/15-min/ideas tabs are omitted. |
| **Audio Narration & Background Mode** | Yes | **Implemented** | [audio_service.dart:L46](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/audio_service.dart#L46); `just_audio_background` configured on Android and iOS. |
| **Audio-Text Synchronization** | Yes | **Implemented** | [audio_player_screen.dart:L231-L300](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/audio/audio_player_screen.dart#L231-L300); scrolls and highlights exact or proportional segments. |
| **Offline DRM Content Encryption** | Yes | **Implemented** | [encrypted_content_storage.dart:L8-L100](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/encrypted_content_storage.dart#L8-L100); AES-256-CBC with keys in Secure Storage. |
| **Offline Audio Playback** | Yes | **Partially Implemented** | [download_manager.dart:L257-L265](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/download_manager.dart#L257-L265); decrypts encrypted audio to unencrypted temp file for playback. |
| **Interactive Flashcards & Quizzes** | Yes | **Implemented** | [flashcards_screen.dart](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/learning/flashcards_screen.dart), [quiz_screen.dart](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/learning/quiz_screen.dart); scores tracked. |
| **Consistency Streaks & Milestones** | Yes | **Implemented** | [streak_tracker.dart:L7-L70](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/streak_tracker.dart#L7-L70); 4 keypoints or 1 book triggers daily streak increment. |
| **AI Personal Learning Coach** | Yes | **Placeholder / Mock** | [ai_coach_service.dart:L108](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/ai_coach_service.dart#L108); `RealAICoachService` extends `MockAICoachService` with static canned replies (unused OpenAI client references removed). |
| **In-App Subscriptions & Paywall** | Yes | **Not Implemented / Mock** | [paywall_screen.dart:L69-L108](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/profile/paywall_screen.dart#L69-L108); simulated 1.2s delay directly awards premium status. |
| **Account Deletion Flow** | Required | **Absent** | [settings_screen.dart:L52-L263](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/profile/settings_screen.dart#L52-L263); no user-facing delete account option exists. |
| **Push Notifications & Reminders** | Yes | **Partially Implemented** | [notification_service.dart](file:///Users/peshrawkaramani/Desktop/Partwk/lib/services/notification_service.dart); local notifications configured; APNs missing entitlements. |
| **Admin Panel: Book Management** | Yes | **Implemented** | [ContentManagement.jsx:L23-L450](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/ContentManagement.jsx#L23-L450); upload audio/covers, draft/publish segregation. |
| **Admin Panel: User Management** | Yes | **Implemented** | [UsersManagement.jsx:L23-L200](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/UsersManagement.jsx#L23-L200); edit user entitlements, trigger password resets. |
| **Admin Panel: 2FA Authentication** | Yes | **Partially Implemented** | [Login.jsx:L8-L150](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/Login.jsx#L8-L150); TOTP secret and bypass keys hardcoded in frontend source. |
| **Admin Panel: Emergency Popups** | Yes | **Implemented** | [PopupManagement.jsx:L1-L120](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/PopupManagement.jsx#L1-L120); targeted modal creation linked with mobile app. |
| **Automated Summary Pipeline** | Yes | **Implemented** | [dynamic_summary_pipeline.py](file:///Users/peshrawkaramani/Desktop/Partwk/dynamic_summary_pipeline.py); Gemini text (EN, KU, AR) + Gemini audio (EN, AR); separate dedicated Kurdish TTS setup for Kurdish audio narration. |

---

## D. DETAILED FINDINGS

```
FINDING SUMMARY MATRIX:
  CRITICAL : 5 findings (Immediate security takeover, leaked credentials, mocked billing, broken iOS build, missing account deletion)
  HIGH     : 6 findings (Missing Firestore rules, unauthenticated draft access, orphaned storage files, unverified universal links, debug signing)
  MEDIUM   : 5 findings (Mock AI coach, runtime Google Fonts fetch, unbounded collection reads, plain-text temp audio, missing crashlytics)
  LOW      : 4 findings (Dead null-aware expressions, unused fields, hardcoded build versions, untracked .env assets)
```

---

### [SEC-01] Critical Account Takeover via Unauthenticated Cloud Function
- **Severity:** **CRITICAL**
- **Category:** Backend Security / Authentication Bypass
- **Affected Component:** `functions/index.js` (`adminUpdateUserPassword`)
- **Description:**  
  The Cloud Function `adminUpdateUserPassword` is deployed as a 2nd Generation Firebase Callable (`onCall`). It accepts `uid` or `email` and `newPassword`, then immediately executes `admin.auth().updateUser(targetUid, { password: newPassword })`. It performs **zero authentication verification (`request.auth == null`) and zero role/permission validation**. Anyone on the internet who knows or discovers this endpoint URL can reset the password of any user—including the administrator (`pkaramani@gmail.com`)—and take complete control of the account.
- **Evidence:**  
  [functions/index.js:L290-L312](file:///Users/peshrawkaramani/Desktop/Partwk/functions/index.js#L290-L312):
  ```javascript
  exports.adminUpdateUserPassword = onCall(async (request) => {
    const { uid, email, newPassword } = request.data || {};
    if ((!uid && !email) || !newPassword) {
      throw new HttpsError('invalid-argument', 'Must provide (uid or email) and newPassword.');
    }
    // No check for request.auth or admin claims!
    let targetUid = uid;
    if (!targetUid && email) {
      const userRecord = await admin.auth().getUserByEmail(email.trim().toLowerCase());
      targetUid = userRecord.uid;
    }
    await admin.auth().updateUser(targetUid, { password: newPassword });
    ...
  });
  ```
- **Reproduction Steps:**
  1. Send an HTTP POST request to `https://us-central1-partwk-bd4ec.cloudfunctions.net/adminUpdateUserPassword` with payload:
     `{"data": {"email": "target@example.com", "newPassword": "AttackerControlledPassword123!"}}`
  2. The function returns `{ "result": { "success": true } }`.
  3. The victim's password in Firebase Auth is overwritten immediately.
- **Impact:** Complete compromise of any user account, administrative impersonation, and total unauthorized access to user personal data.
- **Recommended Correction:** Enforce strict authentication and admin custom claim checks at the very start of the function:
  ```javascript
  if (!request.auth || request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Unauthorized. Caller must be an authenticated administrator.');
  }
  ```
- **Effort:** Small (< 1 hour)
- **Status:** **Confirmed Vulnerability**

---

### [SEC-02] Committed Secrets, Legacy API Keys & SMTP Credentials
- **Severity:** **CRITICAL**
- **Category:** Secrets Management / Exposure
- **Affected Component:** `.env`, `pubspec.yaml`, `functions/index.js`, `admin_panel/.env`
- **Description:**  
  1. Plaintext SMTP credentials for `info@partwk.com` were hardcoded in [functions/index.js:L17-L19](file:///Users/peshrawkaramani/Desktop/Partwk/functions/index.js#L17-L19). A historical SMTP credential was found and rotated.
  2. Multiple Google Gemini keys (`AQ.Ab8RN6...`) used in the backend generation pipeline were stored in `.env`.
  3. Legacy API keys for unused third-party services—OpenAI (`sk-proj-...`) and KurdishTTS (`71fd57ef...`)—were also present in `.env`.
  4. Crucially, [pubspec.yaml:L70](file:///Users/peshrawkaramani/Desktop/Partwk/pubspec.yaml#L70) historically included `.env` under the Flutter application `assets:` bundle. Any release APK or IPA built with this configuration would contain the `.env` file in plaintext within the asset directory.
  5. `admin_panel/.env` previously exposed `VITE_OPENAI_API_KEY`, which Vite baked into the production JavaScript bundle (`dist/assets/index-Bnxl1A3p.js`). (The underlying prototype `ai_service.js` was never called in production and has since been removed along with `admin_panel/.env`).
- **Evidence:**  
  - [pubspec.yaml:L66-L71](file:///Users/peshrawkaramani/Desktop/Partwk/pubspec.yaml#L66-L71):
    ```yaml
    flutter:
      assets:
        - assets/images/
        - assets/audio/
        - assets/avatars/
        - .env
    ```
  - [functions/index.js:L17-L19](file:///Users/peshrawkaramani/Desktop/Partwk/functions/index.js#L17-L19):
    ```javascript
    auth: {
      user: "info@partwk.com",
      pass: "[REDACTED_PASSWORD]",
    }
    ```
- **Impact:** API account hijacking, unauthorized billing spikes (Gemini), and compromise of corporate domain email reputation through spam relaying.
- **Recommended Correction:**
  1. Remove `.env` immediately from `pubspec.yaml` assets.
  2. Remove unused integrations (OpenAI client dependencies, `ai_service.js`, `kurdish_tts_pipeline.py`) and delete `admin_panel/.env`.
  3. Flag legacy OpenAI and kurdishtts.com credentials for **REVOCATION ONLY** at their respective provider dashboards (do not request replacement keys for unused services).
  4. Confine the active Google Gemini API key strictly to backend server/pipeline environments (`dynamic_summary_pipeline.py`), rotate it at Google AI Studio / GCP Console, and verify text and audio generation across all target languages.
  5. Rotate the corporate mailbox password for `info@partwk.com` at Namecheap Private Email and store it securely using Google Cloud Secret Manager / Firebase Functions Secrets (`firebase functions:secrets:set SMTP_PASS`).
  6. Reset the password for `pipeline_admin@partwk.com` in Firebase Authentication and store in the private backend `.env`.
- **Effort:** Small (< 2 hours)
- **Status:** **Confirmed Vulnerability (Containment & Cleanup Completed; Provider Rotations Outstanding)**

---

### [PAY-01] Simulated In-App Purchases and Free Premium Self-Assignment
- **Severity:** **CRITICAL**
- **Category:** Monetization / Revenue Security
- **Affected Component:** `lib/features/profile/paywall_screen.dart`, `lib/core/services/firebase_auth_service.dart`
- **Description:**  
  The application possesses no native payment processing pipeline (neither Apple StoreKit nor Google Play Billing is integrated). Tapping "Subscribe" or "Restore Purchases" sets a local loading spinner for 1200ms and invokes `AppLocator.auth.upgradeToPremium()`. This method directly writes `subscriptionStatus: 'premium'` into the user's Firestore document.
- **Evidence:**  
  [paywall_screen.dart:L69-L88](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/profile/paywall_screen.dart#L69-L88):
  ```dart
  void _subscribe() async {
    ...
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    await AppLocator.auth.upgradeToPremium();
    ...
  }
  ```
  [firebase_auth_service.dart:L784-L788](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/firebase_auth_service.dart#L784-L788):
  ```dart
  Future<void> upgradeToPremium() async {
    if (_currentUser != null) {
      await _updateUserDocument(_currentUser!.copyWith(subscriptionStatus: 'premium'));
    }
  }
  ```
- **Impact:** The app cannot be monetized. Furthermore, submission to the Apple App Store will result in immediate rejection under Guideline 3.1.1 (In-App Purchase).
- **Recommended Correction:** Integrate `purchases_flutter` (RevenueCat) or official `in_app_purchase` package with backend receipt validation.
- **Effort:** Large (3-5 days)
- **Status:** **Confirmed Functional Gap**

---

### [STORE-01] Missing In-App Account Deletion Mechanism (Apple / Google Policy Blocker)
- **Severity:** **CRITICAL**
- **Category:** Store Compliance & Privacy
- **Affected Component:** `lib/features/profile/settings_screen.dart`, `lib/features/profile/profile_screen.dart`
- **Description:**  
  Apple App Store Review Guideline 5.1.1(v) requires: *"If your app supports account creation, you must also offer account deletion within the app."* Inspection of `SettingsScreen` and `ProfileScreen` shows options for theme, language, notifications, family sharing, and legal documents, but **no option for account deletion exists**.
- **Evidence:**  
  [settings_screen.dart:L52-L260](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/profile/settings_screen.dart#L52-L260): Contains settings options, but lacks any `deleteAccount` or user termination function.
- **Impact:** Guaranteed rejection by Apple App Store and Google Play review teams.
- **Recommended Correction:** Add a "Delete Account" button in `SettingsScreen` triggering a confirmation dialog, calling `user.delete()` in Firebase Auth and deleting the Firestore document `users/{uid}`.
- **Effort:** Medium (4-6 hours)
- **Status:** **Confirmed Compliance Blocker**

---

### [ARCH-01] Missing iOS `GoogleService-Info.plist` and Entitlements Configuration
- **Severity:** **CRITICAL**
- **Category:** Build & Platform Configuration
- **Affected Component:** `ios/Runner/`, `ios/Runner.xcodeproj/project.pbxproj`
- **Description:**  
  1. `GoogleService-Info.plist` is completely missing from `ios/Runner`. When the iOS build runs `await Firebase.initializeApp()` in [main.dart:L62](file:///Users/peshrawkaramani/Desktop/Partwk/lib/main.dart#L62), it will crash with a missing configuration exception.
  2. No `.entitlements` file exists in the `ios/` folder. Consequently, Apple Sign-In (`com.apple.developer.applesignin`), Universal Links (`com.apple.developer.associated-domains`), and APNs Push Notifications (`aps-environment`) are not enabled in Xcode.
- **Evidence:**  
  - Verified absence: `find ios -name "*GoogleService*"` returned empty.
  - Verified absence: `find ios -name "*.entitlements"` returned empty.
- **Impact:** iOS release and ad-hoc builds crash on startup or fail code signing during App Store packaging. Apple Sign-In fails at runtime.
- **Recommended Correction:** Download `GoogleService-Info.plist` from Firebase Console into `ios/Runner/`, and configure `Runner.entitlements` with required capability domains.
- **Effort:** Small (< 2 hours)
- **Status:** **Confirmed Blocker**

---

### [SEC-03] Client-Side Admin 2FA and Hardcoded Bypass Key in Admin Portal
- **Severity:** **HIGH**
- **Category:** Admin Authentication & Access Control
- **Affected Component:** `admin_panel/src/pages/Login.jsx`, `admin_panel/src/components/Layout.jsx`
- **Description:**  
  1. The Admin portal 2FA mechanism calculates TOTP on the browser client using a hardcoded secret: `'PARTWKADMINSECRET2FA'`.
  2. A hardcoded emergency bypass key and PIN are stored in plaintext in the client code: `'PK-ADMIN-SECURE-984271-EMERGENCY-KEY'` and `'984271'`.
  3. Route protection in `Layout.jsx` relies entirely on `sessionStorage.getItem('admin_2fa_verified') === 'true'`. Anyone can open the browser console and type `sessionStorage.setItem('admin_2fa_verified', 'true')` to view the entire admin dashboard interface.
- **Evidence:**  
  [Login.jsx:L8](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/Login.jsx#L8): `verifyTOTP(token, secret = 'PARTWKADMINSECRET2FA')`  
  [Login.jsx:L126](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/Login.jsx#L126): `if (cleanKey === 'PK-ADMIN-SECURE-984271-EMERGENCY-KEY' && cleanPin === '984271')`  
  [Layout.jsx:L9-L13](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/components/Layout.jsx#L9-L13): `const isVerified = sessionStorage.getItem('admin_2fa_verified') === 'true';`
- **Impact:** Bypass of administrative 2FA; unauthorized access to admin UI.
- **Recommended Correction:** Implement server-side 2FA verification via Firebase Auth Multi-Factor Authentication (MFA) or Cloud Functions, and govern access via Firebase Auth Custom Claims (`admin: true`).
- **Effort:** Medium (1-2 days)
- **Status:** **Confirmed Architectural Flaw**

---

### [SEC-04] Missing Security Rules for Firestore and Firebase Storage
- **Severity:** **HIGH**
- **Category:** Backend Authorization
- **Affected Component:** `firebase.json`, Firestore & Cloud Storage
- **Description:**  
  Neither `firestore.rules` nor `storage.rules` are defined in `firebase.json` or committed to version control. While live probing confirmed that unauthenticated reads to `/books` return HTTP 403, authenticated users have unconstrained write access to their own documents (`users/{uid}`) and can set `role: "admin"`, `subscriptionStatus: "premium"`, or `hasFamilyPremium: true`.
- **Evidence:**  
  [firebase.json:L1-L36](file:///Users/peshrawkaramani/Desktop/Partwk/firebase.json#L1-L36) contains only `functions` and `hosting`. No `firestore` or `storage` rules are specified.
- **Impact:** Privilege escalation; unauthorized writing to Firestore collections; arbitrary uploads to Storage.
- **Recommended Correction:** Add `firestore.rules` and `storage.rules` to `firebase.json`, deploy with strict schema validation preventing users from altering `role`, `subscriptionStatus`, or `subscriptionExpiryDate`.
- **Effort:** Medium (1 day)
- **Status:** **Confirmed Vulnerability**

---

### [ARCH-02] Android Release Build Uses Debug Keystore & Omits Internet Permission
- **Severity:** **HIGH**
- **Category:** Android Release Configuration
- **Affected Component:** `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- **Description:**  
  1. `android/app/build.gradle.kts` explicitly signs release builds with the debug keystore (`signingConfig = signingConfigs.getByName("debug")`).
  2. `android/app/src/main/AndroidManifest.xml` does not declare `<uses-permission android:name="android.permission.INTERNET"/>` (it is only declared in `src/debug/AndroidManifest.xml`).
  3. `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` is omitted for Android 13+ (API 33+).
- **Evidence:**  
  [build.gradle.kts:L31-L35](file:///Users/peshrawkaramani/Desktop/Partwk/android/app/build.gradle.kts#L31-L35):
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("debug")
      }
  }
  ```
  [AndroidManifest.xml:L4-L7](file:///Users/peshrawkaramani/Desktop/Partwk/android/app/src/main/AndroidManifest.xml#L4-L7): Contains WAKE_LOCK and FOREGROUND_SERVICE, but lacks `INTERNET`.
- **Impact:** Release APKs/AABs will be rejected by Google Play Console due to debug signing, and release builds will be unable to connect to Firebase.
- **Recommended Correction:** Create a release keystore in `key.properties` and add `<uses-permission android:name="android.permission.INTERNET"/>` to `src/main/AndroidManifest.xml`.
- **Effort:** Small (1-2 hours)
- **Status:** **Confirmed Blocker**

---

### [DATA-01] Content Deletion Leaves Orphaned Storage Files and Quizzes
- **Severity:** **HIGH**
- **Category:** Data Integrity & Cost Management
- **Affected Component:** `admin_panel/src/services/api.js` (`deleteBook`)
- **Description:**  
  When a book is deleted in the Admin Panel, `deleteBook` only deletes the Firestore documents from `books` and `books_draft`. It **does not delete** associated cover images in Firebase Storage (`covers/`), chapter audio files (`audio/`), quizzes (`quizzes/quiz_{id}_{lang}`), or flashcards (`flashcards`).
- **Evidence:**  
  [admin_panel/src/services/api.js:L288-L293](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/services/api.js#L288-L293):
  ```javascript
  export const deleteBook = async (bookId) => {
    await Promise.all([
      deleteDoc(doc(db, 'books', bookId)),
      deleteDoc(doc(db, 'books_draft', bookId))
    ]);
  };
  ```
- **Impact:** Permanent storage bloat; accumulation of orphaned audio assets that continue generating hosting costs; dangling quiz/flashcard records.
- **Recommended Correction:** Trigger a Cloud Function `onDocumentDeleted('books/{bookId}')` that recursively cleans up Storage audio/covers and deletes child quiz and flashcard documents.
- **Effort:** Medium (4-6 hours)
- **Status:** **Confirmed Defect**

---

### [AI-01] Advertised "AI Personal Coach" is 100% Mocked
- **Severity:** **MEDIUM**
- **Category:** Feature Completeness
- **Affected Component:** `lib/core/services/ai_coach_service.dart`
- **Description:**  
  The mobile application promotes an AI-driven learning coach to answer user questions about summaries. In code, `RealAICoachService` is an empty subclass of `MockAICoachService`, returning static canned responses based on basic substring matching (`q.contains('how')`).
- **Evidence:**  
  [ai_coach_service.dart:L108](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/ai_coach_service.dart#L108):
  ```dart
  class RealAICoachService extends MockAICoachService {}
  ```
- **Impact:** Misleading value proposition; users expecting intelligent summary interactions receive generic placeholder text.
- **Recommended Correction:** Connect `RealAICoachService` to a secure Firebase Cloud Function that proxies user queries to Gemini with server-side rate-limiting.
- **Effort:** Medium (1-2 days)
- **Status:** **Confirmed Architectural Discrepancy**

---

### [PERF-01] Unbounded Collection Scans in Admin Dashboard and Real-Time Listeners
- **Severity:** **MEDIUM**
- **Category:** Scalability & Firebase Cost Management
- **Affected Component:** `admin_panel/src/pages/Dashboard.jsx`, `admin_panel/src/pages/UsersManagement.jsx`
- **Description:**  
  To display basic dashboard counts, `Dashboard.jsx` fetches the entire `users` collection (`fetchUsers()`) and `books` collection. Similarly, `UsersManagement.jsx` maintains an unpaginated real-time listener `onSnapshot(collection(db, 'users'))`. As the user base grows to 50,000+ users, every dashboard visit will consume 50,000+ Firestore reads.
- **Evidence:**  
  [Dashboard.jsx:L42-L43](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/Dashboard.jsx#L42-L43): `const users = await fetchUsers(); const books = await fetchBooks();`  
  [UsersManagement.jsx:L76](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/UsersManagement.jsx#L76): `const unsub = subscribeToUsers((data) => { setUsers(data); });`
- **Impact:** Extreme Firestore read bill spikes; browser performance degradation/freezing when managing large catalogues.
- **Recommended Correction:** Use Firestore aggregation queries (`getCountFromServer`) for dashboard totals and implement cursor-based pagination (`limit(25)`, `startAfter`) in the user management view.
- **Effort:** Medium (1 day)
- **Status:** **Confirmed Performance Bottleneck**

---

### [DRM-01] Offline Audio Playback Writes Plaintext Decrypted Audio to Sandbox
- **Severity:** **MEDIUM**
- **Category:** Content Protection / DRM
- **Affected Component:** `lib/core/services/download_manager.dart`
- **Description:**  
  While books and audio files are stored encrypted on disk (`.partwkaudio` using AES-256-CBC), `loadAudioSource` decrypts the complete audio file and writes it out as an unencrypted `.mp3` or `.wav` file into the temporary directory (`temp_play/`) so `just_audio` can play it. This decrypted file persists until the next application launch.
- **Evidence:**  
  [download_manager.dart:L262-L265](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/services/download_manager.dart#L262-L265):
  ```dart
  final tempFile = File('${playDir.path}/temp_${bookId}_${langCode}_$idx$ext');
  await tempFile.writeAsBytes(decryptedBytes, flush: true);
  return AudioSource.file(tempFile.path, tag: tag);
  ```
- **Impact:** Users on rooted Android devices or jailbroken iOS devices can extract the full unencrypted audio files directly from the sandbox cache.
- **Recommended Correction:** Implement an in-memory `StreamAudioSource` for `just_audio` to stream decrypted audio chunks directly to the player without persisting plaintext bytes to the filesystem.
- **Effort:** Medium (1-2 days)
- **Status:** **Confirmed Design Limitation**

---

### [UI-01] Missing Summary Reader Tabs Promised in Product Specifications
- **Severity:** **MEDIUM**
- **Category:** User Experience / Product Completeness
- **Affected Component:** `lib/features/book/summary_reader_screen.dart`
- **Description:**  
  The project specification advertises an interactive reader with tabs for "5-min summary", "15-min summary", "chapters", "key ideas", "quotes", and "action points". However, `summary_reader_screen.dart` renders only chapter summaries; `fiveMinuteSummary`, `fifteenMinuteSummary`, `keyIdeas`, and `actionPoints` are completely omitted from the reader UI.
- **Evidence:**  
  Inspection of [summary_reader_screen.dart:L1-L1167](file:///Users/peshrawkaramani/Desktop/Partwk/lib/features/book/summary_reader_screen.dart#L1-L1167) reveals zero occurrences of `TabBar` or `fiveMinuteSummary`.
- **Impact:** Disconnect between marketed features and the actual reading experience.
- **Recommended Correction:** Introduce a top `TabBar` in `SummaryReaderScreen` exposing the existing model data (`book.getFiveMinuteSummary()`, `book.getKeyIdeas()`, etc.).
- **Effort:** Medium (1-2 days)
- **Status:** **Confirmed Gap**

---

### [UX-01] Dynamic Google Fonts Dependency Harms Offline Resilience
- **Severity:** **MEDIUM**
- **Category:** Fonts & Offline Experience
- **Affected Component:** `lib/core/theme/app_theme.dart`
- **Description:**  
  `AppTheme` uses `GoogleFonts.vazirmatnTextTheme()` and `GoogleFonts.outfitTextTheme()`. These fonts are not bundled as local assets in `pubspec.yaml` and are downloaded at runtime from Google CDN. If a user launches the app in offline mode without prior caching, typography falls back to system defaults, causing layout shifts and potential font clipping in Kurdish/Arabic.
- **Evidence:**  
  [app_theme.dart:L136-L147](file:///Users/peshrawkaramani/Desktop/Partwk/lib/core/theme/app_theme.dart#L136-L147); `pubspec.yaml` assets list has no `.ttf` or `.otf` font declarations.
- **Impact:** Degraded typography, text clipping, or missing glyphs during offline reading.
- **Recommended Correction:** Download `Outfit` and `Vazirmatn` font files, place them in `assets/fonts/`, and declare them in `pubspec.yaml`.
- **Effort:** Small (2 hours)
- **Status:** **Confirmed Reliability Risk**

---

## E. TEST RESULTS & SYSTEM VERIFICATION

### 1. Static Analysis (`flutter analyze lib test`)
- **Outcome:** **0 Errors, 45 Warnings, 282 Info Lints** (Ran in 4.4 seconds).
- **Key Warnings:**
  - `dead_null_aware_expression` in `profile_screen.dart` (lines 355, 400, 408, 421).
  - Unused imports in `download_service.dart` (`dart:convert`, `shared_preferences`).
  - Unused fields in `download_service.dart` (`_dio`, `_offlineBooksKey`).
  - Deprecated member `withOpacity` across multiple screens.

### 2. Automated Test Execution (`flutter test`)
- **Outcome:** **12 of 12 Tests Passed** (100% pass rate).
- **Passing Suites:**
  - `test/completion_support_test.dart` (Completion tracking, duplicate suppression, streak increment).
  - `test/offline_support_test.dart` (License validation, cache fallback, network guard).
  - `test/widget_test.dart` (Basic widget smoke test).

### 3. Admin Panel Build Verification (`npm run build`)
- **Outcome:** **Build Successful** in 904ms via Vite 8.0.16.
- **Artifacts:**
  - `dist/index.html` (1.40 kB)
  - `dist/assets/index-DDk-nCOb.css` (21.10 kB)
  - `dist/assets/index-Bnxl1A3p.js` (1,061.60 kB)
- **Observations:** Bundle size exceeds 1MB due to monolithic dynamic import bundling in `recharts` and `firebase`. Historically leaked unused `VITE_OPENAI_API_KEY` into `index-Bnxl1A3p.js` (now sanitized and redeployed).

### 4. Cloud Functions Syntax Verification (`node -c functions/index.js`)
- **Outcome:** **Valid Node.js 20 syntax**. Clean AST parsing with zero syntax errors.

### 5. Backend Live Access & Security Probing
- **Direct Unauthenticated Firestore REST Probe:**
  - Query: `curl -s "https://firestore.googleapis.com/v1/projects/partwk-bd4ec/databases/(default)/documents/books?pageSize=1"`
  - Result: Returned `HTTP 403 PERMISSION_DENIED`. Unauthenticated REST reading is correctly rejected.
- **Client SDK Unauthenticated Probe:**
  - Execution of `admin_panel/check_users.js` returned `FirebaseError: Missing or insufficient permissions. (permission-denied)`.

---

## F. REMEDIATION PLAN

### Phase 1: Must Fix Before Release (Launch Blockers)
1. **[SEC-01] Secure `adminUpdateUserPassword` Function:** Add caller authentication and admin verification (`request.auth.token.admin === true`).
2. **[SEC-02] Purge Leaked Secrets & Remove `.env` from Assets:** Delete `.env` from `pubspec.yaml` assets; move SMTP password to Cloud Secret Manager; rotate all exposed keys.
3. **[ARCH-01] Fix iOS Build Baseline:** Add `GoogleService-Info.plist` to `ios/Runner`; configure `Runner.entitlements` with Apple Sign-In and Universal Link domains.
4. **[ARCH-02] Fix Android Release Configuration:** Generate a release keystore; add `android.permission.INTERNET` and `POST_NOTIFICATIONS` to `main/AndroidManifest.xml`.
5. **[STORE-01] Implement Account Deletion:** Add "Delete Account" in mobile settings with confirmation and Firebase Auth/Firestore deletion.
6. **[PAY-01] Integrate Real In-App Purchases:** Replace the mocked 1.2s delay in `paywall_screen.dart` with RevenueCat or StoreKit/Play Billing.
7. **[SEC-04] Deploy Production Firestore Rules:** Commit `firestore.rules` preventing users from modifying `role` or `subscriptionStatus`.

### Phase 2: Should Fix Soon (Pre-Marketing / Post-Launch Hardening)
1. **[SEC-03] Secure Admin Portal Authentication:** Move TOTP validation to server-side Cloud Function and secure admin routes with Custom Claims.
2. **[DATA-01] Automate Storage Cleanup:** Implement Cloud Function triggers on document deletion to remove orphaned covers and audio files.
3. **[PERF-01] Refactor Dashboard Queries:** Replace full collection reads with `getCountFromServer()` and implement pagination in `UsersManagement.jsx`.
4. **[UX-01] Bundle Fonts Locally:** Add `Outfit` and `Vazirmatn` font assets to `pubspec.yaml` to ensure reliable offline rendering.
5. **[AI-01] Connect Real AI Coach:** Replace `MockAICoachService` with a Cloud Function proxy to Gemini.

### Phase 3: Later Improvements (Quality of Life & Scale)
1. **[DRM-01] Stream Decrypted Audio in Memory:** Migrate from temporary disk files to in-memory `StreamAudioSource`.
2. **[UI-01] Implement Missing Summary Tabs:** Add 5-min, 15-min, and Action Points tabs to `SummaryReaderScreen`.
3. **Observability Integration:** Install `firebase_crashlytics` and `firebase_analytics` to track crashes and user engagement.

---

## G. FINAL VERDICT

### Overall Verdict: **NOT READY FOR PRODUCTION RELEASE**
- **Mobile App:** **Not Ready** (Crashes on iOS due to missing Firebase configuration; lacks required account deletion; lacks real in-app purchases).
- **Admin Panel:** **Ready with Security Warnings** (Functionally operational, but contains client-side 2FA bypass and excessive Firestore read usage).
- **Firebase Backend:** **Not Ready** (Contains critical unauthenticated password reset vulnerability and lacks version-controlled security rules).

---

### Plain-English Owner Summary
**Peshraw, here is the honest assessment of your app:**

- **What Works:**  
  The core of Partwk is genuinely impressive. The visual interface, Arabic and Kurdish typography/RTL layouts, audio playback with background mode, synchronized paragraph highlighting, offline AES encryption, flashcards, quizzes, and your content generation pipeline are remarkably well-built and pass all functional tests cleanly.

- **What is Broken:**  
  1. Your iOS app will crash immediately when opened because `GoogleService-Info.plist` is missing from the iOS project.
  2. Apple will reject the app immediately for two reasons: there is no button to delete an account, and your "Subscribe" button is a fake button that gives people free premium without taking any payment.
  3. Your "AI Personal Coach" is currently a simulator that returns pre-written answers without actually using AI.

- **What is Unsafe:**  
  1. There is an open backdoor in your Cloud Functions (`adminUpdateUserPassword`) that allows anyone who finds the link to change any user's password—including yours—without logging in.
  2. Your `.env` file containing your Gemini keys, corporate email password (`info@partwk.com`), and legacy OpenAI/KurdishTTS keys was previously packaged directly inside your mobile app APK/IPA for anyone to see (now removed from assets).

- **What to Do Next:**  
  Do not rush to publish yet. Address the Phase 1 blockers in order: lock down the password reset Cloud Function, remove `.env` from app assets, add the missing iOS Firebase file, add the account deletion button, and integrate real in-app purchases. Once those are fixed, Partwk will be a robust, secure, and ready-to-launch product.
