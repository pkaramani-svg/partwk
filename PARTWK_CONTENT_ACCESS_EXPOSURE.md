# Paid-content exposure and compatible protection plan

**Status:** confirmed source-level exposure; no content-delivery change was made.

## Current retrieval paths

1. `firestore.rules` permits public reads of `/books/{bookId}`. Those published documents contain the complete chapter text and per-language `audioUrl` values, deserialised by `lib/models/book.dart` and read by the summary reader.
2. `admin_panel/src/pages/ContentManagement.jsx` uploads chapter audio to `audio/...` with Firebase Storage `uploadBytes`, then persists the result of `getDownloadURL` into the public book document.
3. The audio player streams that URL. `DownloadManager` retrieves the same URL before encrypting its local offline copy.
4. Current Storage rules require an authenticated caller for `/audio/**`, but a Firebase `getDownloadURL` bearer token can continue to retrieve an object while that token remains valid; changing Storage rules later does not revoke an already-issued token URL.

Accordingly, a non-Premium user can read full paid text from public book documents and can obtain paid audio URLs from the same documents. Hiding a button or changing only Storage rules does not close either path.

## Compatibility-preserving plan

1. Add a backend-owned access classification per book: `sample` for the one established complete free book and `premium` for all other full books. Do not infer this from UI placement.
2. Keep the selected sample's existing public text/audio paths unchanged.
3. Move premium chapter text out of the public `/books` representation. Retain public catalogue metadata and fetch premium chapter content through an authenticated callable that verifies `/entitlements/{uid}`.
4. Stop persisting Firebase `getDownloadURL` values for premium audio. The trusted backend should issue short-lived URLs only after entitlement verification, and the player/downloader should obtain/refresh them before streaming or downloading.
5. Classify and migrate paid audio one book at a time, test the player/downloader and offline licence expiry, then remove old public token references. Only after that migration should Storage access be tightened.

This preserves the complete free sample and the established reading/listening experience. It requires a deliberate delivery migration because existing permanent URL tokens cannot be made safe by a Firestore or Storage rule edit alone.
