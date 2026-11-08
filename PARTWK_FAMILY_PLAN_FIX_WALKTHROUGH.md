# Partwk family-plan implementation walkthrough

**Starting point:** `9888e5d2fd7d5f28570afbe9560edffdd79c7a9a` on `security-phase1-fixes`, with a materially dirty pre-existing workspace. No reset, deployment, live membership change, invitation/email, charge, or production migration was performed.

## Delivered local changes

| Area | Files | Result |
|---|---|---|
| Trusted family model | `functions/index.js` | Callable invite/status/accept/cancel/remove/leave/admin-removal operations with Firestore transactions, one reserved-or-active slot, member uniqueness, self-link prevention, paid-recipient block and backend audit records. Pending invitations remain until accepted or cancelled, matching the established experience rather than introducing a new expiry/cooldown policy. |
| Privacy/rules | `firestore.rules`, `storage.rules` | Removes member access to another `/users/{uid}` root; prevents ordinary writes to legacy family fields; makes entitlement/family projections backend-only. Authenticated audio reads are deliberately preserved for the current player/downloader. |
| Mobile family | `lib/core/services/family_service.dart`, `settings_screen.dart`, `firebase_auth_service.dart` | App calls backend callables and reads only its own family/entitlement projection. Legacy cross-account writes and email-array discovery are disabled. |
| Purchase safety | `purchase_service.dart`, `paywall_screen.dart`, `pubspec.yaml` | Adds official Flutter `in_app_purchase` integration (3.3.1 at implementation time), loads actual store product data and sends purchase data to a callable before completion. If product id/verifier configuration is absent, checkout is unavailable; no simulated success remains. |
| Offline cap | `licence_manager.dart` | Local download licence is bounded by entitlement expiry as well as 30 days and existing seven-day online validation cap. Offline devices cannot learn an immediate revocation until they reconnect; the cap is the deliberate limit. |
| Admin/migration | `UsersManagement.jsx`, `tools/family_migration_dry_run.js` | Removes legacy comma-separated relationship editing. Dry-run only reports ambiguous legacy records and never writes/accepts/grants access. |

## Data and entitlement flow

`/users/{uid}` remains private profile/progress/settings data. The backend creates:

- `/families/{primaryUid}`: owner and one pending invite or one active `memberUid`.
- `/familyMemberships/{memberUid}`: minimal pending/active/removed membership projection.
- `/entitlements/{uid}`: backend-owned effective access with source and expiry.

The app can read only its own projection. A family entitlement expires with the primary entitlement and is removed immediately on leave/removal. Client fields (`familyMembers`, `hasFamilyPremium`, `subscriptionStatus`) are not accepted as entitlement proof.

## Preserved content behaviour and remaining delivery limit

The existing app stores published book metadata (including chapter `audioUrl` values) in public Firestore documents. The player streams those URLs and `DownloadManager` downloads the same URLs before encrypting offline copies. Storage read access therefore remains authenticated, which preserves registered/anonymous guest sample playback, existing language audio selection, streaming, download and synchronisation behaviour. Covers and catalogue metadata remain public; drafts remain admin-only.

This is not title-level Premium enforcement: Firebase tokenised download URLs may continue to work independently of a later rules change. No compatible signed-URL/content classification service exists in this workspace, so I did not break working playback with an incomplete replacement. Production work must first classify the one sample book and Premium assets, issue short-lived authorised URLs, migrate the player/downloader, and test it before tightening `/audio/**` further.

## Tests actually run

- `node --check functions/index.js` — passed.
- `npm run build --prefix admin_panel` — passed. Vite reported pre-existing/size optimisation warnings only.
- Local Firestore emulator, actual current `firestore.rules`, fabricated test identities: `scratch/family_fix_rules_test.js` — **5/5 passed**. It verified ordinary primary and anonymous clients cannot create direct relationships, a member cannot read primary root data, and a member can read only its own entitlement/membership projection.
- Local Storage emulator, actual current `storage.rules`: `scratch/storage_preservation_test.js` — **2/2 passed**. An authenticated free account can read the existing audio path (preserving full sample/player behaviour); unauthenticated access is denied.
- Local Auth, Firestore and Functions emulators: `scratch/functions_family_emulator_test.js` — passed against the loaded callable implementations. It exercised invite/status/accept, duplicate acceptance, member invitation-chain refusal, leave, cancellation, concurrent invite reservation, expired-primary refusal, independently-paid-recipient refusal, ordinary-admin refusal, and an Auth-emulator custom-claim authorised removal. Removal and leaving set the member entitlement projection to inactive. The test used only `.test.invalid` identities and isolated emulator records. Existing welcome-email triggers ran for fixture documents but had no emulator SMTP secret and logged that delivery was skipped; no message was sent.
- Isolated migration fixture plus `GCLOUD_PROJECT=partwk-family-functions FIRESTORE_EMULATOR_HOST=127.0.0.1:18080 node tools/family_migration_dry_run.js` — passed read-only. Five legacy links were reported for manual review: two competing owners for one account, one self-link, one independently paid member, one missing account, and the unverified owner’s links. It made no migration write or entitlement change.

Flutter analysis/build/runtime screenshots were blocked by the installed Flutter SDK’s Dart VM crash (`runtime/vm/cpuinfo_macos.cc:42`), before dependency resolution or app startup. Consequently the new `cloud_functions` and `in_app_purchase` packages are declared but `pub get`, Flutter compile, real device tests and screenshots remain unverified. No HTML mockup is presented as runtime proof.

Only `/Users/peshrawkaramani/Flutter/flutter/bin/flutter` was found on this machine; it is Flutter 3.12.0 and crashes even for `--version`, so no compatible local SDK was available. On a separate compatible macOS environment, install a current stable Flutter SDK without replacing this installation, then run from this checkout: `flutter pub get`, `flutter analyze`, `flutter test`, and a debug Android/iOS build. The Function emulator used its bundled Node 20 while `functions/package.json` requests Node 22; callable tests passed, but deployment/runtime verification must use Node 22.

## Content-access investigation (completed source trace)

Published `/books/{bookId}` documents are public and contain full chapter text plus `audioUrl` values (`firestore.rules`, `lib/models/book.dart`, `admin_panel/src/pages/ContentManagement.jsx`). The reader uses that public text; the player streams the stored URL; `DownloadManager` retrieves the same URLs before encrypting local copies. The admin uploader uses Firebase Storage `uploadBytes` followed by `getDownloadURL`, which creates long-lived Firebase token URLs. Those URLs can be fetched directly while their token remains valid, independently of a later Storage-rules change.

Therefore a Storage-rule-only change cannot implement “one free full sample, all other books Premium” without breaking existing playback *and* leaving already-issued token URLs as a bypass. The smallest compatible protection is: add an explicit per-book access classification, move paid chapter text out of public book documents (or return it from an entitlement-checked callable), and replace `getDownloadURL` for paid audio with short-lived URLs issued after checking the backend entitlement projection. Keep the already-selected sample’s text/audio public/authenticated through the existing paths. This is a necessary delivery migration, not a rules tweak, so it was intentionally not implemented locally; doing only part would either break the player or fail to protect paid assets.

## Store-console and backend setup still required

1. Create the identical annual subscription product in App Store Connect and Play Console; put its production/test identifier in `PARTWK_ANNUAL_PRODUCT_ID`. Configure localised storefront price; reference offer is US$39.99/year, but UI uses store-returned price.
2. Configure Apple App Store Server API credentials/notifications and a Google Play service account, RTDN Pub/Sub verification and product/base-plan mapping. Implement the platform-specific verifier in `verifyStorePurchase` and a verified notification/reconciliation handler before enabling checkout. It is deliberately fail-closed now.
3. Configure Functions emulator/client routing during test builds and add Android/iOS sandbox tester accounts. Never point test receipts at production entitlement records.
4. Run `node tools/family_migration_dry_run.js` against an explicitly selected export/emulator. Review self-links, missing accounts, multi-owner conflicts, independently paid members and unverified/expired primaries. Create pending invitations only after manual approval; never auto-accept or downgrade independent paid access.

## Scoped deployment order (do not execute without approval)

1. Deploy Functions and rules together to staging, with no legacy entitlement migration enabled.
2. Configure/verify store server credentials, product identifiers and sandbox lifecycle webhooks.
3. Run callable, Firestore/Storage and real sandbox purchase tests; verify cancellation, renewal, grace, refund/revocation and notification replay.
4. Review migration dry-run and manually resolve ambiguities.
5. Release mobile/admin clients that exclusively use the callable flow, then deploy approved rules/functions together. Do not claim title-level Storage entitlement enforcement until tokenised URLs/content classification are replaced and tested; existing Firebase download URLs can outlive a rule evaluation.

## Phone test checklist

- Primary paid sandbox account: invite registered free account; repeat/concurrent invite cannot reserve more than one slot.
- Recipient: sees in-app pending record, accepts once; independent paid recipient gets clear refusal.
- Member: cannot see primary progress/settings/token or invite controls; can leave.
- Primary: cancels pending invite or removes active member; the single slot becomes available immediately, preserving the existing product behaviour.
- Test cancellation/renewal/expiry/refund notification with sandbox state; family access exactly follows owner expiry.
- Confirm English/Kurdish Sorani/Arabic layouts and RTL direction on a real device.
- Confirm a free account cannot fetch premium audio via a direct path; confirm intentional free samples/covers still work after content classification.
