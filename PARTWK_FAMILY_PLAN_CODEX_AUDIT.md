# Partwk Premium family-member audit — independent Codex report

**Audit date:** 3 November 2026 (Europe/Rome)  
**Scope:** Flutter app, React admin panel, Firebase source/configuration and isolated Local Emulator Suite checks. Audit only: no application code, deployed rules, production data, credentials, invitations, email, store purchase, migration or deployment was changed.

## Executive assessment

The intended offer (one paying Premium owner plus one separately logged-in member for US$39.99/year) is **not launch-ready**. The current source has an email-list sharing mechanism, not a secure invitation and membership system. It does not establish recipient consent/ownership, does not enforce one slot, does not prevent chains or multiple families, has no removal/replacement flow, and has no trusted subscription provider or payment verification.

The current uncommitted Firestore rules explain a genuine regression in the existing client flow: the primary client writes its own `familyMembers` array and then attempts to write `hasFamilyPremium` on a different account. That latter write is now denied. The member’s later attempt to persist the same flag is also denied. Those denials are correct security behaviour; restoring the previous deployed open rules would be unsafe.

The tightened rules nevertheless contain serious remaining defects: every signed-in user, including an anonymous Firebase user, can author a `familyMembers` relation on their own document; a listed address can read the owner’s entire `/users/{uid}` root document; and any authenticated user can read all `/audio/**` objects, independently of Premium entitlement. The rules protect private note/highlight subcollections but root-profile privacy is not preserved.

## Exact inspected state and evidence boundaries

| Item | Observed value |
|---|---|
| Working branch | `security-phase1-fixes` |
| HEAD | `9888e5d2fd7d5f28570afbe9560edffdd79c7a9a` — 28 June 2026, “Obfuscate admin authentication error messages for security compliance” |
| Working tree | materially dirty; `firestore.rules` and `storage.rules` are untracked; Flutter, functions and admin files have pre-existing modifications. This report does not attribute uncommitted changes to a commit. |
| Rule files tested | untracked `firestore.rules` (142 lines) and `storage.rules` (50 lines), selected by current `firebase.json` |
| Emulator | Firebase CLI 15.26.0; Firestore emulator v1.22.0; Java 21.0.10; isolated project `partwk-codex-audit`; Firestore 18080 and Storage 19199 |
| App tooling | Flutter 3.12.0 invocation crashed in its Dart VM before analysis/run; `flutter` was not on PATH. No Flutter runtime screenshots were captured. |
| Production | no production writes. An existing local forensic snapshot says production ruleset `ef8a4e3e…` was captured 2 Nov 2026 and was authenticated-open. I did not independently re-fetch it from production, so it is corroborating local evidence, not a fresh deployed-config assertion. |

The audit test artifacts I added are `firebase.codex-audit.json`, `scratch/codex_audit_firebase.json`, and `scratch/codex_family_emulator_test.js`. They use fictitious `.test.invalid` identities and local emulator data only.

## Architecture and actual current flow

1. The mobile paywall waits 1.2 seconds and calls `upgradeToPremium`; this simply writes `subscriptionStatus: 'premium'` locally/client-side ([paywall_screen.dart](lib/features/profile/paywall_screen.dart:75), [firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:784)). There is no StoreKit, Play Billing, RevenueCat, purchase SDK, receipt or server verification dependency in [pubspec.yaml](pubspec.yaml:9).
2. A Premium/pro user sees the Settings family section. It accepts any string containing `@` and immediately calls `linkFamilyMember`; there is no invitation, email delivery, expiry, acceptance, recipient authentication, revoke, removal, or replacement UI ([settings_screen.dart](lib/features/profile/settings_screen.dart:27), [settings_screen.dart](lib/features/profile/settings_screen.dart:120)).
3. `linkFamilyMember` appends the lowercase email to the owner document, then queries all matching user documents and tries to set `hasFamilyPremium: true` on each ([firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:759)). The second action is a cross-account client write.
4. On member login, `_fetchUserData` queries an owner whose `familyMembers` contains the member email; if that owner has `premium`, `pro`, or `admin`, it sets local family access and tries to write `hasFamilyPremium` to the member’s own record ([firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:294)). It does not check primary expiry, suspension, cancellation/grace, duplicate owner, or one-slot state.
5. `UserModel.isPremium` accepts either direct Premium/pro or `hasFamilyPremium`, and only evaluates the *member’s own* expiry field ([user.dart](lib/models/user.dart:65)). The owner’s expiry is not propagated/evaluated.
6. The React panel lets an admin enter arbitrary comma-separated member emails ([UsersManagement.jsx](admin_panel/src/pages/UsersManagement.jsx:548)). Its browser client then looks up matching accounts and writes `hasFamilyPremium` before updating the owner record ([api.js](admin_panel/src/services/api.js:22)). It has no server transaction, one-member validation, override reason, or server-side audit record.
7. Firestore only limits fields such as `subscriptionStatus` and `hasFamilyPremium`; it does not protect the semantic relation in `familyMembers` ([firestore.rules](firestore.rules:33), [firestore.rules](firestore.rules:42)). A membership-listed account is explicitly allowed to read the owner root document ([firestore.rules](firestore.rules:25)).
8. Cloud Functions contain welcome/expiry email triggers and an admin password reset callable only. There is no family callable, subscription-webhook verifier, receipt validator or family reconciliation job ([index.js](functions/index.js:168), [index.js](functions/index.js:277), [index.js](functions/index.js:319)). The scheduler downgrades only direct Premium/pro accounts on expiry and does not revoke/reconcile family flags.
9. Offline user data is cached after login ([firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:322)); downloaded-book access delegates to `LicenceManager`, but there is no inspected owner-expiry binding or documented offline family policy. The UI’s direct expiry check omits expiry entirely for family access ([book_details_screen.dart](lib/features/book/book_details_screen.dart:1077)).

## Emulator tests actually executed

Command (with the locally installed Android Studio Java runtime):

```text
firebase emulators:exec --config firebase.codex-audit.json --only firestore,storage "node scratch/codex_family_emulator_test.js" --project partwk-codex-audit
```

The test loaded the actual current rule files (the emulator startup log names absolute `.../firestore.rules`) and used Firebase client SDK requests. All 11 expected outcomes passed:

| Request/identity | Result |
|---|---|
| eligible primary adds two member emails | allowed — proves no one-slot rule |
| ordinary authenticated free user writes own family relation | allowed |
| authenticated anonymous user creates own family relation | allowed |
| linked member reads primary root | allowed |
| member sets own `hasFamilyPremium` | denied |
| primary sets member `hasFamilyPremium` | denied |
| unrelated user and unauthenticated caller read primary root | denied |
| linked member queries owner by membership | allowed |
| signed-in free user reads `/audio/test.mp3` | allowed; unauthenticated read denied |

The denial checks deliberately produce emulator `PERMISSION_DENIED` log entries; those are expected successful tests, not test failures. Direct testing of Functions was blocked: `firebase.json` has no Functions emulator configuration and the implementation has no family callable to exercise. Storage tests establish current rule behaviour but cannot validate a Premium-only DRM policy because no such rule/path policy exists.

## Requirement matrix

| # | Requirement | Status | Evidence |
|---:|---|---|---|
| 1 | Eligible primary only; one member | **Fail** | Any signed-in/anonymous owner can write arbitrary arrays; Settings only hides UI. Emulator allowed free/anonymous and two-member writes. |
| 2 | Separate private progress, notes, highlights, settings | **Partially Implemented** | Notes/highlights subcollections deny cross-user reads, but linked member reads owner root containing progress, settings and FCM token: rules 25–31. |
| 3 | Follows renewal/expiry/refund/revocation/grace | **Fail** | No billing verifier; login checks only owner status, not expiry; scheduler only changes direct owner. |
| 4 | Cancellation retains paid term | **Unverified** | No cancellation/state model. |
| 5 | Members cannot invite/chains | **Fail** | `hasFamilyPremium` users are not excluded by rules; direct arbitrary relations allowed. |
| 6 | Free/signed-out/anonymous cannot invite | **Fail** | Emulator allowed free and anonymous; unauthenticated cannot access Firestore. |
| 7 | Duplicate/concurrent/replay cannot exceed slot | **Fail** | No transaction, reservation or maximum length; two-member test allowed. |
| 8 | A member belongs to one family | **Fail** | Email may occur in any number of owner arrays; query uses `.limit(1)`. |
| 9 | Bound, expiring, single-use, revocable invitation | **Fail** | No invitation model/function/UI. |
| 10 | Recipient ownership verified | **Fail** | Primary only types email; no acceptance or verified-recipient check. |
| 11 | Removal/replacement updates access | **Fail** | No mobile removal/replacement control; admin writes are non-atomic and only best-effort. |
| 12 | Server replacement limit/explanation | **Fail** | No server enforcement or policy. |
| 13 | Preserve independently paid subscriber | **Fail** | `hasFamilyPremium` is blindly toggled; no paid-status conflict handling. |
| 14 | Sign-out/reinstall/device cannot bypass | **Partially Implemented** | Rules gate protected fields, but app caches access/offline state and relationship remains account-email based; policy not established. |
| 15 | Users cannot edit protected entitlement fields | **Partially Implemented** | Emulator confirms `hasFamilyPremium`, role and direct subscription writes are denied; `familyMembers` remains editable and confers privacy/read access. |
| 16 | Admin obeys same limit / explicit override | **Fail** | Panel allows comma-separated arbitrary members; rules’ `isAdmin()` bypasses all limits. |
| 17 | Overrides authorised and recorded | **Partially Implemented** | Rules recognize UID/custom claim/verified configured email, and `audit_logs` is append-only, but admin family changes do not write an audit record. |
| 18 | No private-root/history/notes/bookmarks/tokens/settings exposure | **Fail** | Linked member full-root read leaks root fields; emulator proved access. Notes/highlights subcollections are isolated. |
| 19 | Missing/deleted/invalid primary safe | **Partially Implemented** | Empty query yields no family flag locally, but stale cached/member flag and no reconciliation/migration are unresolved. |
| 20 | Offline policy bounded by known expiry | **Fail** | No documented owner-linked licence expiry; UI check tests only entitlement booleans. |

## Findings

### Critical — no trusted billing or entitlement source

**References:** [paywall_screen.dart](lib/features/profile/paywall_screen.dart:75), [firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:784), [pubspec.yaml](pubspec.yaml:9).  
**Reproduce:** sign in with a registered non-guest account, select Subscribe or Restore. Both wait then call the same client-side `upgradeToPremium` method. Current rules deny changing an existing direct subscription field, so it may fail in the running app; under the previously open rules it would have been client-grantable.  
**Impact:** no real purchase, restore, receipt validation, renewal, refund/revocation or grace lifecycle exists. The shown paid offer is unsupported.

### Critical — current rules block the implemented mobile link operation

**References:** [firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:768), [firestore.rules](firestore.rules:42).  
**Reproduce:** eligible primary calls `linkFamilyMember`; cross-account `update(hasFamilyPremium: true)` is denied. The isolated emulator confirmed this.  
**Impact:** Settings reports “Linked” after awaiting a method that catches this error, even though durable member entitlement was not written. This is a confirmed current defect and a security-rule regression relative to the archived authenticated-open rule.

### High — arbitrary family relations and root-profile disclosure

**References:** [firestore.rules](firestore.rules:25), [firestore.rules](firestore.rules:42), [firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:759).  
**Reproduce:** free/anonymous caller writes `familyMembers` in their own permitted document; member address listed in any owner then reads that owner’s root document. Emulator confirmed both.  
**Impact:** one-slot, eligibility, chain and single-family invariants are unenforced, and root data such as progress/settings/notification token can be exposed.

### High — access can outlive primary entitlement

**References:** [firebase_auth_service.dart](lib/core/services/firebase_auth_service.dart:303), [user.dart](lib/models/user.dart:65), [index.js](functions/index.js:277).  
**Impact:** member privilege is based on owner status only at login, ignores the owner expiry, and cached `hasFamilyPremium` can remain. Expiry scheduler does not reconcile members. Refund/revocation/grace do not exist.

### High — admin panel violates the declared one-member offer

**References:** [UsersManagement.jsx](admin_panel/src/pages/UsersManagement.jsx:147), [UsersManagement.jsx](admin_panel/src/pages/UsersManagement.jsx:548), [api.js](admin_panel/src/services/api.js:43).  
**Impact:** unlimited comma-separated accounts, no atomic operation, no paid-subscriber conflict handling, and no auditable override reason.

### Medium — Premium audio/content is not entitlement-protected in Storage

**References:** [storage.rules](storage.rules:24).  
**Impact:** every authenticated user can access `/audio/**`; published books are public ([firestore.rules](firestore.rules:65)). This may be acceptable for preview/free material, but it cannot enforce Premium audio. It should be treated separately from public covers and published catalog data.

### Medium — price and claim discrepancy

**References:** [app_localizations.dart](lib/core/localization/app_localizations.dart:243), [app_localizations.dart](lib/core/localization/app_localizations.dart:489), [app_localizations.dart](lib/core/localization/app_localizations.dart:735).  
English/Kurdish/Arabic display `$39 / Year` (not the confirmed `$39.99/year`) and also advertise “SAVE 67%” without a shown comparator. The admin panel has no customer paywall/price display. Store-localized pricing cannot be confirmed because there is no store billing integration. No £39 discrepancy was found in searched source.

## Historical/regression investigation

The committed June history is sparse. The initial tracked commit contains the client family mechanism, but neither rules file was tracked. The current branch’s relevant code change history has only the initial commit; therefore the source cannot identify a specific June code commit that introduced a family defect.

The local archived deployed Firestore rules state `allow read, write: if request.auth != null` and are timestamped 2 November 2026. Compared with the current local rules, they would have permitted both cross-account entitlement writes used by the old flow. The present rules correctly deny those operations. Classification:

| Item | Classification |
|---|---|
| Cross-account client write now denied | **Confirmed regression introduced by rule hardening**, based on archived deployed-rule snapshot plus current emulator. Exact deployment/build tested in June is unavailable. |
| Old implementation’s direct cross-account entitlement write and owner-root disclosure | **Pre-existing security defect supported by historical evidence**; open rules permitted it, not a safe design to restore. |
| Missing invitation, one-slot, payment lifecycle and removal model | **Pre-existing/current defect, historical origin unknown**; current source has no implementation and commit history cannot date it. |
| Current uncommitted rules being deployed | **Unverified**; `firebase.json` points to them locally, but deployment was not performed/verified. |

## Real UI and localisation verification

No valid running Flutter screenshot was produced. The installed Flutter invocation crashes before starting/analyzing, so the requested real-app English, Kurdish Sorani and Arabic screens, invitation outcome, member/free/guest absence states, removal/replacement, and paywall could not be runtime-verified. Existing HTML previews/screenshots in `scratch/` were not treated as app evidence. Source confirms localisation strings exist in all three languages, but source review is not layout verification.

## Antigravity comparison

`PARTWK_FAMILY_PLAN_AUDIT_REPORT.md` was not present anywhere searched under the workspace (case-insensitive filename search, depth 3). I therefore cannot make claim-by-claim comparisons or establish whether it reviewed the same commit/rules. This section is **unverified due to the absent report**, rather than a disagreement.

## Prioritised correction plan (not implemented)

1. **Block launch and remove unsupported payment/restore assertions** until platform billing is integrated. Use StoreKit/Google Play products and a trusted backend/webhook verifier as source of entitlement truth; carry owner expiry/grace/revocation state server-side.
2. **Replace email arrays/flags with a trusted, transactional family model**, preferably server callable operations: owner UID, member UID, state (`pending/active/revoked`), recipient-bound single-use token/expiry, and one reserved-or-active slot enforced in one transaction. Do not grant access based on a client-written boolean.
3. **Do not grant root `/users/{uid}` reads to members.** Store a minimal entitlement projection accessible to the member, or return it only through a callable. Keep progress, settings, tokens and profile documents owner-only.
4. **Move linking/removal/replacement/reconciliation to trusted backend code.** Preserve independent paid entitlement; do not cancel/bill/overwrite it. Require authorised admin overrides with reason and immutable audit record.
5. **Define and implement access policy** for expiry, cancellation, grace, refund/revocation, offline licences and missing accounts. Reconcile all memberships after lifecycle changes and bound cached/offline licences by server-known expiry.
6. **Align product/marketing:** use the verified store-localized price; reference US$39.99/year, remove or substantiate 67% savings, and only advertise a family benefit once it exists securely.
7. **Test and deploy safely:** add emulator tests for all six caller types, races, replay/revocation/expiry, direct paths and Storage distinctions; test a staged backend/release before production. A migration is needed for existing `familyMembers`/`hasFamilyPremium` records, with owner/member conflict review. Store-console product configuration and server credentials/webhooks are dependencies.

## Walkthrough / launch decision

What works: separate app accounts have their own stored root documents and private note/highlight subcollections; tightened rules deny direct changes to protected entitlement fields; public covers and authenticated audio are distinctly configured.

What fails: the family operation is a non-consensual email append, cannot reliably grant entitlement after rule hardening, has no secure membership lifecycle, exposes owner root data to listed members, and has no verified billing system. Admin actions have the same structural defects. Price is `$39`, not `$39.99`.

What changed since June where provable: only the local archived rule comparison proves that formerly open authenticated rules would allow the old cross-account writes and the new rules deny them. It does not prove which exact June binary was tested or that the old behaviour was correct.

Before launch: implement the targeted trusted family/entitlement design and billing lifecycle above, migrate safely, test it in emulators and a staging runtime, verify actual mobile UIs/access paths, and deploy reviewed rules/functions together. Do **not** restore the archived permissive production rules.
