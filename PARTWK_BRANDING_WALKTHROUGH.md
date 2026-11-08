# Partwk branding refresh walkthrough

**Scope:** local branding assets and screens only. No app-store submission, Firebase deployment, email delivery, production data change, or authentication-flow change was performed.

## Supplied artwork and treatment

Source: `assets/images/partwk_new_source.png` (700 × 700 RGBA). Its visible artwork was cropped only to its existing transparent bounds and uniformly resized; it was not redrawn, stretched, recoloured, or altered. The source remains in the workspace.

The resulting reusable transparent artwork is `assets/images/partwk_emblem.png`. Android uses it in a padded transparent adaptive-icon foreground over the existing white background. Its outer visible pixels remain inside Android's 66/108 safe circle. iOS uses an opaque white 1024 × 1024 master (`assets/images/app_icon_ios.png`) without rounded corners; iOS will apply the icon mask itself.

## Changed implementation

| Area | Files | Change |
|---|---|---|
| Source/derived assets | `assets/images/partwk_new_source.png`, `assets/images/partwk_emblem.png`, `assets/images/app_icon_foreground.png`, `assets/images/app_icon_ios.png` | Exact supplied emblem, transparent in-app/Android foreground, opaque iOS master. |
| Android launcher | `android/app/src/main/res/mipmap-*`, `drawable-*`, `mipmap-anydpi-v26/*`, `values*/styles.xml` | Regenerated with the existing `flutter_launcher_icons` configuration, including adaptive foreground/background resources. |
| iOS launcher | `ios/Runner/Assets.xcassets/AppIcon.appiconset/*` | Regenerated all AppIcon sizes from the opaque master. |
| Welcome/authentication | `lib/features/auth/onboarding_screen.dart`, `lib/features/auth/login_register_screen.dart` | Replaced the old/generic mark with the new transparent emblem. Small-height and RTL-safe layout adjustments prevent overflow without changing authentication actions. |
| Email templates | `admin_panel/public/email_logo.png`, `functions/index.js` | Replaced the hosted image asset and updated the shared logo block used by welcome, Premium, renewal, and password-reset templates. This only becomes live after a future authorised Hosting + Functions deployment; no email was sent. |
| Reproducibility/testing | `tools/generate_partwk_brand_assets.py`, `test/branding_layout_test.dart`, `integration_test/branding_runtime_test.dart`, `scratch/branding_previews/` | Deterministic asset generator, responsive widget coverage, actual emulator captures and launcher-mask previews. |

The established Flutter splash branding was deliberately not replaced: it is a separate Zentori splash asset/configuration, not the previous Partwk launcher/login logo.

## Visual evidence

### Actual Android emulator screenshots

These are captures of the running isolated debug application, not HTML mockups:

- [Android startup splash](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/android-splash-runtime.png)
- [Welcome — English](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/welcome_en_runtime.png)
- [Login — English](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/login_en_runtime.png)
- [Registration — English](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/registration_en_runtime.png)
- [Registration — Kurdish Sorani](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/registration_ku_runtime.png)
- [Registration — Arabic RTL](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/registration_ar_runtime.png)

### Rendered launcher previews

These are static previews made from the generated production assets, not device screenshots:

- [Android circle](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/android-circle-preview.png)
- [Android squircle](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/android-squircle-preview.png)
- [Android rounded square](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/android-rounded_square-preview.png)
- [Android square](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/android-square-preview.png)
- [iOS square master](/Users/peshrawkaramani/Desktop/Partwk/scratch/branding_previews/ios-square-preview.png)

## Checks actually run

| Check | Result |
|---|---|
| `dart run flutter_launcher_icons` with the isolated Flutter SDK | Passed; Android adaptive and iOS AppIcon resources regenerated. |
| iOS AppIcon manifest/image validation | Passed: 19 referenced assets, all opaque RGB. |
| `flutter test test/branding_layout_test.dart` | Passed: 6/6 layouts across compact/large English, Kurdish Sorani and Arabic RTL states. |
| `flutter test integration_test/branding_runtime_test.dart -d emulator-5554` with `PARTWK_ISOLATED_TEST=1` and emulator dart-defines | Passed: 1/1; produced the actual screenshots above. |
| `flutter build apk --debug` with `PARTWK_ISOLATED_TEST=1`, `USE_FIREBASE_EMULATORS=true`, and `FIREBASE_EMULATOR_HOST=127.0.0.1` | Passed. Existing plugin/Kotlin optimisation warnings were reported separately; no new branding compilation error occurred. |
| `node --check functions/index.js` | Passed. |
| `npm run build --prefix admin_panel` | Passed. |

The resulting **isolated-emulator-only** Android APK is [partwk-branding-emulator-debug.apk](/Users/peshrawkaramani/Desktop/Partwk/build/app/outputs/flutter-apk/partwk-branding-emulator-debug.apk). It embeds debug-only Firebase-emulator routing and must not be distributed or used as a production/standalone phone build.

## iOS validation boundary

The installed tooling found Xcode 26.3, CocoaPods 1.17, and iOS Simulator runtime support. The dependency retry established that the current Flutter/Firebase pods require iOS 15.0. Approval to end iOS 13–14 support was received, so `ios/Podfile` and `ios/Runner.xcodeproj/project.pbxproj` now explicitly declare iOS 15.0. `pod install` now resolves all declared dependencies successfully. The unsigned Simulator compile completed and produced `build/ios/Debug-iphonesimulator/Runner.app/Runner`. No iOS launch is claimed: the local CoreSimulator installation currently reports the iOS 26.3 runtime but has no available or booted device to install it on.

The final build/launch validation command is:

```text
env -u DEEPSEEK_API_KEY .tool/flutter-3.47.5-stable/bin/flutter pub get
env -u DEEPSEEK_API_KEY .tool/flutter-3.47.5-stable/bin/flutter build ios --simulator --debug --no-codesign
```

Then launch in an iOS Simulator and confirm the launcher and English/Kurdish/Arabic auth views. No iOS App Store action is required.

## Remaining manual checks

1. Install a normal, non-emulator-routed debug/release candidate on a physical Android device and inspect the icon under the device's own launcher mask.
2. Create or install an available iOS Simulator device for the installed runtime, then launch the already-built app and inspect the launcher and English/Kurdish/Arabic auth views.
3. Before future email deployment, publish `admin_panel/public/email_logo.png` to the configured Hosting target and deploy the changed Function template together, then send only approved test emails.

No deployment or publication was performed as part of this work.
