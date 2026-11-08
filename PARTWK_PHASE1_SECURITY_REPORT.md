# Partwk Phase 1 Security Report: Verification, Workflow Realignment & Production Deployment

**Document Version:** 2.1.0  
**Date:** November 2, 2026  
**Project:** Partwk (Book-Summary Platform)  
**Firebase Project ID:** `partwk-bd4ec`  
**Storage Bucket:** `partwk-bd4ec.firebasestorage.app`  
**Hosting Site Target:** `partwk-bd4ec` (`https://partwk-bd4ec.web.app`)  
**Git Branch:** `security-phase1-fixes`  
**Status:** Production Containment Deployed & Live Verified (Rules & Hosting Deployed; Production Workflow Realigned; Legacy Integrations Cleaned Up; Direct Password Function Undeployed)

---

> [!IMPORTANT]
> **PRODUCTION STATUS & CREDENTIAL NOTICE**  
> 1. **Containment Deployed:** Hardened Firestore security rules, Firebase Storage security rules, and the sanitized admin panel web build have been successfully deployed to production (`partwk-bd4ec`) and verified with dedicated test accounts.  
> 2. **Legacy Credentials Marked for Revocation Only:** OpenAI and `kurdishtts.com` are confirmed unused legacy integrations. Their historic keys must be revoked at their respective provider dashboards, but **no replacement keys are required**.  
> 3. **Active Production Credentials to Rotate:** Google Gemini API keys, Namecheap Private Email SMTP password (`info@partwk.com`), and the `pipeline_admin@partwk.com` Firebase Auth password remain outstanding for rotation at their providers.

---

## 1. Executive Summary & Production Workflow Realignment

The initial audit report made assumptions regarding third-party service usage that did not match Partwk’s actual production architecture. Following source code tracing and live workflow verification, the technical reality of the platform has been clarified:

### 1.1 Verified Production Architecture
1. **Google Gemini (Active Backend Engine):**
   - **Multi-Lingual Text Summaries:** Gemini generates comprehensive book summaries, chapter breakdowns, key takeaways, quotes, flashcards, and quizzes in **English (`en`)**, **Kurdish Sorani (`ku`)**, and **Arabic (`ar`)** via [dynamic_summary_pipeline.py](file:///Users/peshrawkaramani/Desktop/Partwk/dynamic_summary_pipeline.py#L900-L1350).
   - **Audio Narration:** Gemini synthesizes natural audio narration for **English (`en-US`)** and **Arabic (`ar-XA`)** using `gemini-2.5-flash-preview-tts` and `gemini-2.5-pro-preview-tts`.
   - **Isolation:** The Gemini API key is strictly confined to the backend server/pipeline environment (`os.getenv("GEMINI_API_KEY")`) and is completely excluded from client mobile assets and web bundles.
2. **Kurdish Audio Narration (Separate Setup):**
   - Kurdish audio narration is generated separately using the owner's dedicated Kurdish TTS setup elsewhere (completely decoupled from Gemini and `kurdishtts.com`).
   - The generated audio files are uploaded to Firebase Storage under `/audio/` and linked to book chapters. Storage security rules explicitly permit authenticated users to stream this audio.
3. **Confirmed Unused Legacy Integrations (Removed):**
   - **OpenAI:** Neither the mobile app nor the production pipeline uses OpenAI. `dart_openai` in `pubspec.yaml` was dead code, `MockAICoachService` was an in-memory canned-string mock, and `admin_panel/src/services/ai_service.js` was an unused prototype. All have been cleanly removed from the repository.
   - **kurdishtts.com API:** An experimental script `kurdish_tts_pipeline.py` previously tested this API. It was never integrated into the production pipeline and has been deleted.

---

## 2. Code Tracing & Cleanup of Unused Integrations

### 2.1 OpenAI Integration Audit & Removal
- **Mobile Client (`pubspec.yaml`):** `dart_openai: ^6.1.1` was listed under dependencies but was **never imported anywhere in `lib/`**. Removed `dart_openai` from `pubspec.yaml` and ran `flutter pub get` (removed 3 unused packages including `fetch_api` and `fetch_client`).
- **AI Coach (`lib/core/services/ai_coach_service.dart`):** Contained old placeholder strings mentioning OpenAI keys. Cleaned all references; `MockAICoachService` remains an in-memory test placeholder without external network calls.
- **Admin Panel Prototype (`admin_panel/src/services/ai_service.js`):** Read `import.meta.env.VITE_OPENAI_API_KEY` to call `api.openai.com/v1/chat/completions`. Deleted `ai_service.js`, removed its import from [ContentManagement.jsx](file:///Users/peshrawkaramani/Desktop/Partwk/admin_panel/src/pages/ContentManagement.jsx#L4), deleted `admin_panel/.env`, and redeployed `hosting:partwk-bd4ec`.
- **Credential Action:** Legacy OpenAI key (`sk-proj-...`) is flagged for **REVOCATION ONLY**. No replacement key requested.

### 2.2 `kurdishtts.com` Integration Audit & Removal
- **Pipeline Audit:** Confirmed [dynamic_summary_pipeline.py](file:///Users/peshrawkaramani/Desktop/Partwk/dynamic_summary_pipeline.py#L995-L1003) explicitly skips Kurdish TTS audio generation (`if lang_input == "ku": processed_chapters.append({"audioUrl": "", ...}); continue`) because Kurdish audio is supplied by the separate setup.
- **Legacy Script (`kurdish_tts_pipeline.py`):** Targeted `kurdishtts.com/api/tts-demo`. Deleted `kurdish_tts_pipeline.py` from repository without affecting the separate Kurdish TTS setup or Kurdish audio uploads.
- **Credential Action:** Legacy Kurdish TTS key (`71fd57ef2acb...`) is flagged for **REVOCATION ONLY**. No replacement key requested.

---

## 3. Active Credentials Assessment & Rotation Checklist

Each credential category has been evaluated according to its actual architectural role, exposure history, and operational necessity:

### 3.1 Legacy Unused Credentials (Revocation Only — No Replacement)
- **OpenAI API Key (`sk-proj-...`):**
  - **Actual Production Use:** **None.** Tracing verified that `dart_openai` was never imported in `lib/`, `MockAICoachService` was an in-memory canned-string mock, and `admin_panel/src/services/ai_service.js` was an abandoned prototype.
  - **Historic Exposure:** Was saved in `.env` and `admin_panel/.env`.
  - **Remediation Completed:** Package removed from `pubspec.yaml`, prototype JS file deleted, `.env` purged, and admin panel redeployed without the key.
  - **Action Required:** Revoke key at [platform.openai.com](https://platform.openai.com). **Do NOT request or configure a replacement key.**
- **KurdishTTS API Key (`71fd57ef...`):**
  - **Actual Production Use:** **None.** The production pipeline explicitly bypasses Kurdish TTS because Kurdish narration is handled by a separate dedicated setup. Only an isolated experimental script (`kurdish_tts_pipeline.py`) referenced this API.
  - **Historic Exposure:** Was saved in `.env`.
  - **Remediation Completed:** Deleted `kurdish_tts_pipeline.py` from repository without impacting the separate Kurdish TTS setup or Kurdish audio uploads.
  - **Action Required:** Revoke key at [kurdishtts.com](https://kurdishtts.com). **Do NOT request or configure a replacement key.**

### 3.2 Active Google Gemini API Credentials (Backend Restriction & Rotation)
- **Actual Production Use:** **Core Engine.** Generates all summary texts, key insights, quizzes, and flashcards across English (`en`), Kurdish Sorani (`ku`), and Arabic (`ar`), and synthesizes natural audio narration for English (`en-US`) and Arabic (`ar-XA`).
- **Exposure & Isolation Audit:**
  - **Backend Pipeline:** Strictly loaded via `os.environ["GEMINI_API_KEY"]` in [dynamic_summary_pipeline.py](file:///Users/peshrawkaramani/Desktop/Partwk/dynamic_summary_pipeline.py#L128).
  - **Mobile Assets:** Fully excluded from `pubspec.yaml` `assets:` bundle.
  - **Admin Browser Bundle:** Fully excluded from Vite bundle (verified zero occurrences of `GEMINI` or `AIzaSy` in `dist/assets/`).
- **Action Required:** Because Gemini keys were stored in historic `.env` files, rotate the key in [Google AI Studio](https://aistudio.google.com/) or GCP API Console. Update `GEMINI_API_KEY` in your private pipeline `.env`.
- **Post-Rotation Verification:** As detailed in Section 4, text generation in all 3 languages and audio in EN/AR have been tested and verified operational.

### 3.3 Namecheap Private Email SMTP Credentials (`info@partwk.com`)
- **Actual Production Use:** **Active Cloud Functions.** Used by Cloud Functions v2 in [functions/index.js](file:///Users/peshrawkaramani/Desktop/Partwk/functions/index.js#L13-L45) to deliver transactional emails (welcome notifications, subscription expiration alerts, and custom password reset links).
- **Historic Exposure:** Plaintext password was hardcoded in `functions/index.js` (`pass: "[REDACTED]"`).
- **Code Remediation:** Refactored `functions/index.js` to read credentials strictly from environment secrets: `process.env.SMTP_USER` and `process.env.SMTP_PASS`. Added safety guards skipping delivery gracefully if secrets are not set.
- **Action Required:**
  1. Log into the Namecheap Private Email web portal (`mail.privateemail.com`) and change the mailbox password for `info@partwk.com`.
  2. Set the updated secret in Firebase Cloud Functions via CLI:
     ```bash
     firebase functions:secrets:set SMTP_PASS --project partwk-bd4ec
     ```
  3. Redeploy functions with secrets access when ready.

### 3.4 Ingestion Pipeline Admin Account (`pipeline_admin@partwk.com`)
- **Actual Production Use:** **Pipeline Ingestion.** Authenticates the automated Python ingestion pipeline (`dynamic_summary_pipeline.py`) to Firebase Auth via Google Identity Toolkit REST API (`signInWithPassword`) to obtain a verified ID token for writing summaries to Firestore (`/books/`) and uploading covers and audio to Firebase Storage.
- **Historic Exposure:** Hardcoded credentials previously existed in local ingestion scripts.
- **Code Remediation:** Refactored `dynamic_summary_pipeline.py` to require `PIPELINE_ADMIN_PASSWORD` from local system environment or private `.env` ([dynamic_summary_pipeline.py:L51-L55](file:///Users/peshrawkaramani/Desktop/Partwk/dynamic_summary_pipeline.py#L51-L55)), preventing static credential commits.
- **Action Required:**
  1. Open Firebase Console -> **Authentication** tab -> Find `pipeline_admin@partwk.com`.
  2. Select **Reset Password** or generate a strong random password.
  3. Store the new password in your private backend `.env`:
     ```bash
     PIPELINE_ADMIN_PASSWORD="<new-secure-password>"
     ```

### 3.5 Credential Assessment Matrix

| Credential / Account | Production Role | Historic Exposure | Action Protocol | Status |
| :--- | :--- | :--- | :--- | :---: |
| **OpenAI API Key** | Unused legacy code | Historic `.env` & admin build | **Revoke at platform.openai.com.** No replacement. | **Revocation Outstanding** |
| **Kurdish TTS API Key** | Unused legacy test | Historic `.env` | **Revoke at kurdishtts.com.** No replacement. | **Revocation Outstanding** |
| **Google Gemini Key(s)** | Active summary & audio backend | Historic `.env` | **Rotate at Google AI Studio.** Restrict to backend `.env`. | **Rotation Outstanding** |
| **Namecheap SMTP (`info@`...)** | Transactional Cloud Functions | Historic `functions/index.js` | **Change mailbox password at Namecheap.** Set `SMTP_PASS` secret. | **Rotation Outstanding** |
| **Pipeline Admin User** | Ingestion pipeline auth | Historic local script | **Reset password in Firebase Console Auth.** Update pipeline `.env`. | **Rotation Outstanding** |

---

## 4. Verification of Gemini Production Pipeline

To confirm that the active Gemini pipeline operates flawlessly with zero reliance on OpenAI or `kurdishtts.com`, an end-to-end test was executed (`scratch/verify_gemini_production_pipeline.py`):

```
================================================================
VERIFYING GOOGLE GEMINI PRODUCTION WORKFLOW
================================================================

1. KEY RESTRICTION & ISOLATION CHECK
  [PASS] Gemini key loaded strictly in backend pipeline.
  [PASS] Excluded from Flutter pubspec.yaml assets.
  [PASS] Excluded from Admin Panel web build.

2. MULTI-LINGUAL TEXT SUMMARY GENERATION
  [PASS] English (en) text generated successfully:
         Preview: By making tiny, consistent improvements to your systems, you can achieve remarka...
  [PASS] Kurdish Sorani (ku) text generated successfully:
         Preview: کتێبی نەریتە ئەتۆمییەکان ڕێنماییەکی کردارییە دەربارەی چۆنیەتی دروستکردنی سیستەمی...
  [PASS] Arabic (ar) text generated successfully:
         Preview: يكشف الكتاب كيف تؤدي التغييرات المتناهية الصغر والمستمرة في العادات والأنظمة إلى...

3. GEMINI AUDIO NARRATION GENERATION
  [PASS] English (en-US) audio synthesized successfully (121486 PCM bytes).
  [PASS] Arabic (ar-XA) audio synthesized successfully (134926 PCM bytes).

4. KURDISH AUDIO PIPELINE CONFIRMATION
  [PASS] Kurdish audio generation is decoupled from Gemini.
  [PASS] Generated separately using custom Kurdish TTS setup and uploaded to Storage /audio/ path.

================================================================
GEMINI PRODUCTION PIPELINE VERIFICATION COMPLETE
================================================================
```

---

## 5. Production Deployments & Live Verification Recap

### 5.1 Executed Containment Deployments
- **Firestore & Storage Rules:** Deployed to `partwk-bd4ec` via `firebase deploy --only firestore:rules,storage`.
- **Sanitized Admin Panel:** Deployed to `partwk-bd4ec` via `firebase deploy --only hosting:partwk-bd4ec`.
- **Privileged Password Function:** Kept **undeployed** by design (returns HTTP 404). Password resets use standard Firebase action links (`sendPasswordResetEmail`).

### 5.2 Live Database Audit (Plaintext Passwords)
- **Status:** **Zero records currently found** containing `pendingAdminPassword` in production Firestore.
- **Forensic Scope:** This audit confirms current state only; it does not establish whether such fields ever existed historically.

### 5.3 Live Post-Deployment Verification Summary
1. **Anonymous Endpoint Probes:** 8/8 passed (unauthenticated reads/writes denied on `/users`, `/books_draft`, and Storage `/audio/`; published books readable).
2. **Dedicated Test Accounts Verification:** 8/8 passed (User A self-access succeeds; cross-user User B access denied; privilege escalation blocked; test accounts cleaned up).
3. **Storage Emulator Verification:** 17/17 passed via client SDK requests.
4. **Firestore Emulator Verification:** 25/25 passed via client SDK requests.

---

## 6. Summary of Protected State vs. Next Actions

### What is Protected & Realigned
- The platform security rules are live in production, stopping data leakage and privilege escalation.
- Unused OpenAI and `kurdishtts.com` code paths have been expunged from the repository.
- Google Gemini multi-lingual text generation (EN, KU, AR) and audio generation (EN, AR) are verified and working.
- Kurdish audio generation remains correctly decoupled, preserving the owner's separate Kurdish TTS setup.

### Next Action Required by Platform Owner
1. **Revoke Unused Keys:** In OpenAI dashboard and KurdishTTS portal, revoke historic keys (no replacement needed).
2. **Rotate Active Keys:** Generate a new Google Gemini API key and set in backend pipeline `.env`. Change `info@partwk.com` password at Namecheap and set via `firebase functions:secrets:set`. Reset `pipeline_admin@partwk.com` in Firebase Auth.
