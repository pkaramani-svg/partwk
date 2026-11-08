import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

import 'package:partwk/main.dart' as app;
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/protected_text_service.dart';
import 'package:partwk/features/book/summary_reader_screen.dart';
import 'package:partwk/features/book/book_details_screen.dart';
import 'package:partwk/models/book.dart';

const String _primaryCustomToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2lkZW50aXR5dG9vbGtpdC5nb29nbGVhcGlzLmNvbS9nb29nbGUuaWRlbnRpdHkuaWRlbnRpdHl0b29sa2l0LnYxLklkZW50aXR5VG9vbGtpdCIsImlhdCI6MTc5MzkxMzY1NCwiZXhwIjoxNzkzOTE3MjU0LCJpc3MiOiJmaXJlYmFzZS1hZG1pbnNkay1mYnN2Y0BwYXJ0d2stYmQ0ZWMuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJzdWIiOiJmaXJlYmFzZS1hZG1pbnNkay1mYnN2Y0BwYXJ0d2stYmQ0ZWMuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJ1aWQiOiI5WnB2ZW9PekFlZG5FN1ozSjV2aUMzaFBmZ0MzIn0.XckltBpycIMFxPjkMaEqOMCcu-Q5bLsmDZ8tpcLgHqV5QkTYaz_iWHPc4l8JMUJFMWAHztBt9DmWqrXeC3zLM1KEYpbi-VmSn4g9puO2gadcN7ec6JKk1LqNhkjI0iM7dBS4OXEBUi6ChmWAGtjhW_ZC8QCunC8Hf1whXIubFJ0rW9K-FrWKlb_pMxqlRgHmJ62GUTHPddDLbsKyk3Qags29q0BM_lJFvqnbZIY8nDzTR_LQY0mO91ISZd3okkgV72t_NKbZtQs0BYzZKsSvf_FBov1QMPNfbuFB7OSxzk18I5FJWLP0qO1vkDmQMREMGUF5gQmVnei7ps2E-iOI7g";

const String _familyCustomToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2lkZW50aXR5dG9vbGtpdC5nb29nbGVhcGlzLmNvbS9nb29nbGUuaWRlbnRpdHkuaWRlbnRpdHl0b29sa2l0LnYxLklkZW50aXR5VG9vbGtpdCIsImlhdCI6MTc5MzkxMzY1NCwiZXhwIjoxNzkzOTE3MjU0LCJpc3MiOiJmaXJlYmFzZS1hZG1pbnNkay1mYnN2Y0BwYXJ0d2stYmQ0ZWMuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJzdWIiOiJmaXJlYmFzZS1hZG1pbnNkay1mYnN2Y0BwYXJ0d2stYmQ0ZWMuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJ1aWQiOiJnWHBHa1hWczZaYndKbkxhTERHTnFoa2M2YWsyIn0.M2XGlwrn1b1ZcsTlPT7SGXyc0x8sZT59q16TjV52wCgI5eTnGuQlphJMyIDda8F6fXCN4gN5HOuA1HcFDGm6Qri6EhGp1fiF_ICkyLjhg6OPwgPs2uoTd2b_pe7w2lwH7nCw_vp4ajt63LTLRZL1_y8y53uTnl-K6EYqKhtNbHWRHyAdquVSFMDKPhUqHve_8UplEvsFqDYwK8xWQptAd7XAjtrEAxH9JRMICyqY6gyzDWYJX8y7QkLiBcwCqbrC1R8kanxerTKOut2R7Fc-azDuA0hOU7cS2HgyHwcaTkV0_B5hT2Vpsd2m9TP7WuKtMJ1wPZBfEC0M5S-Gn0VA3A";

const String _freeCustomToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL2lkZW50aXR5dG9vbGtpdC5nb29nbGVhcGlzLmNvbS9nb29nbGUuaWRlbnRpdHkuaWRlbnRpdHl0b29sa2l0LnYxLklkZW50aXR5VG9vbGtpdCIsImlhdCI6MTc5MzkxMzY1NCwiZXhwIjoxNzkzOTE3MjU0LCJpc3MiOiJmaXJlYmFzZS1hZG1pbnNkay1mYnN2Y0BwYXJ0d2stYmQ0ZWMuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJzdWIiOiJmaXJlYmFzZS1hZG1pbnNkay1mYnN2Y0BwYXJ0d2stYmQ0ZWMuaWFtLmdzZXJ2aWNlYWNjb3VudC5jb20iLCJ1aWQiOiJiSUk3SHptRDlCT05MYTZ2OG4xeXYwYnc3WXgxIn0.lbTP00tVN9n1xnQ0CZWh_bnNJkzIUzIP1IJVZSaw0ZH3-6rRY1SeqXgQoSbP0NZJkwlnfvDm3x5rgvVFSvdmVuQLtrPhQGsHPsXmCev93Yh6wX07J8F4M_U5Ol8sx08JOoWnX5o_f_Dzjkyv1IgCBX4YMmcTJhxojzJH8Nu46ZKGcO9ZNKZKWDfiUtU4eU5CifC6LRAyfeT6Igr25lmlAu3P2dLwmKABfOPAo9UpetVYbnhP5fQK3QOzVfXrSlVkEwL9v0pDDejlFjbmESa0X1h4l5ufdf7E_91cEG-pkRhwx-0PaErgTDC4MfiI8bMhapnIxfzEIFUiAiwM1i7zWg";

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live production-configured verification on device against partwk-bd4ec', (tester) async {
    debugPrint('=== STARTING LIVE PRODUCTION VERIFICATION ===');

    // 1. Launch real production-configured app
    await tester.runAsync(app.main);
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(app.navigatorKey.currentState, isNotNull);
    await tester.runAsync(binding.convertFlutterSurfaceToImage);

    // Directory for screenshots accessible without special Android 15 permissions
    Directory? storageDir;
    await tester.runAsync(() async {
      storageDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    });

    // Helper to capture screenshots
    Future<void> capture(String name) async {
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() async {
        final bytes = await binding.takeScreenshot(name);
        final file = File('${storageDir!.path}/$name.png');
        await file.writeAsBytes(bytes);
      });
      debugPrint('[SCREENSHOT_SAVED] ${storageDir!.path}/$name.png');
    }

    // Helper to switch app language
    Future<void> setAppLang(String langCode) async {
      final context = app.navigatorKey.currentContext!;
      Provider.of<AppLanguageState>(context, listen: false).setLanguage(langCode);
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    // =========================================================================
    // TEST 1: PRIMARY PREMIUM ACCOUNT (pkaramani@gmail.com)
    // =========================================================================
    debugPrint('\n--- TEST 1: Primary Premium Account (pkaramani@gmail.com) ---');
    await tester.runAsync(() async {
      await AppLocator.auth.signOut();
      await FirebaseAuth.instance.signInWithCustomToken(_primaryCustomToken);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (AppLocator.auth.currentUser != null && AppLocator.auth.currentUser!.email == 'pkaramani@gmail.com') {
          break;
        }
      }
    });

    final primaryUser = AppLocator.auth.currentUser;
    expect(primaryUser, isNotNull);
    expect(primaryUser!.email, 'pkaramani@gmail.com');
    expect(primaryUser.subscriptionStatus, 'premium');
    expect(primaryUser.isPremium, isTrue, reason: 'Primary account must have active Premium entitlement');
    debugPrint('✓ Primary user signed in: ${primaryUser.email}, isPremium: ${primaryUser.isPremium}');

    // Test atomic_habits (isPremium: true) in English, Kurdish, Arabic
    for (final lang in ['en', 'ku', 'ar']) {
      await setAppLang(lang);

      // 1.1 Reader Test
      debugPrint('  [Primary] Opening atomic_habits Reader in $lang...');
      app.navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const SummaryReaderScreen(bookId: 'atomic_habits')),
      );
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(SummaryReaderScreen), findsOneWidget);
      expect(find.textContaining('Offline mode'), findsNothing);
      expect(find.textContaining('Connect to the internet'), findsNothing);
      await capture('live_primary_read_$lang');

      app.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // 1.2 Audio Test
      debugPrint('  [Primary] Opening atomic_habits Audio & text panel in $lang...');
      app.navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const BookDetailsScreen(bookId: 'atomic_habits')),
      );
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(BookDetailsScreen), findsOneWidget);
      expect(find.textContaining('Unable to load book text'), findsNothing);
      await capture('live_primary_audio_$lang');

      app.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }

    // =========================================================================
    // TEST 2: LINKED FAMILY MEMBER (chrpa1997@gmail.com)
    // =========================================================================
    debugPrint('\n--- TEST 2: Linked Family Account (chrpa1997@gmail.com) ---');
    await tester.runAsync(() async {
      await AppLocator.auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await FirebaseAuth.instance.signInWithCustomToken(_familyCustomToken);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (AppLocator.auth.currentUser != null && AppLocator.auth.currentUser!.email == 'chrpa1997@gmail.com') {
          break;
        }
      }
    });

    final familyUser = AppLocator.auth.currentUser;
    expect(familyUser, isNotNull);
    expect(familyUser!.email, 'chrpa1997@gmail.com');
    expect(familyUser.hasFamilyPremium, isTrue, reason: 'Family member must retain hasFamilyPremium: true from Firestore profile');
    expect(familyUser.isPremium, isTrue, reason: 'Family member must have valid Premium access');
    debugPrint('✓ Family user signed in: ${familyUser.email}, hasFamilyPremium: ${familyUser.hasFamilyPremium}, isPremium: ${familyUser.isPremium}');

    // Test atomic_habits in en, ku, ar for family member
    for (final lang in ['en', 'ku', 'ar']) {
      await setAppLang(lang);

      // 2.1 Reader Test
      debugPrint('  [Family] Opening atomic_habits Reader in $lang...');
      app.navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const SummaryReaderScreen(bookId: 'atomic_habits')),
      );
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(SummaryReaderScreen), findsOneWidget);
      expect(find.textContaining('Offline mode'), findsNothing);
      await capture('live_family_read_$lang');

      app.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // 2.2 Audio Test
      debugPrint('  [Family] Opening atomic_habits Audio in $lang...');
      app.navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const BookDetailsScreen(bookId: 'atomic_habits')),
      );
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(BookDetailsScreen), findsOneWidget);
      expect(find.textContaining('Unable to load book text'), findsNothing);
      await capture('live_family_audio_$lang');

      app.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }

    // =========================================================================
    // TEST 3: FREE ACCOUNT DENIED PREMIUM BOOKS (pk@karamani.com)
    // =========================================================================
    debugPrint('\n--- TEST 3: Free Account Denied Premium (pk@karamani.com) ---');
    await tester.runAsync(() async {
      await AppLocator.auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await FirebaseAuth.instance.signInWithCustomToken(_freeCustomToken);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (AppLocator.auth.currentUser != null && AppLocator.auth.currentUser!.email == 'pk@karamani.com') {
          break;
        }
      }
    });

    final freeUser = AppLocator.auth.currentUser;
    expect(freeUser, isNotNull);
    expect(freeUser!.email, 'pk@karamani.com');
    expect(freeUser.isPremium, isFalse, reason: 'Free account must not have Premium access');
    expect(freeUser.hasFamilyPremium, isFalse);
    debugPrint('✓ Free user signed in: ${freeUser.email}, isPremium: ${freeUser.isPremium}');

    // Attempt to open atomic_habits (isPremium: true)
    await setAppLang('en');
    app.navigatorKey.currentState!.push(
      MaterialPageRoute(builder: (_) => const SummaryReaderScreen(bookId: 'atomic_habits')),
    );
    for (var i = 0; i < 16; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 250));
    }
    // Must show Upgrade to Premium error, NOT Offline Mode
    expect(find.textContaining('Offline mode'), findsNothing, reason: 'Must NOT display Offline Mode error for permission denial');
    expect(find.textContaining('Upgrade to Premium'), findsWidgets, reason: 'Must display Upgrade to Premium message/button');
    await capture('live_free_premium_denied');

    app.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    // =========================================================================
    // TEST 4: NON-PREMIUM BOOK FULLY ACCESSIBLE (sapiens, isPremium: false)
    // =========================================================================
    debugPrint('\n--- TEST 4: Non-Premium Book Accessible (sapiens) ---');
    for (final lang in ['en', 'ku', 'ar']) {
      await setAppLang(lang);

      debugPrint('  [Free] Opening sapiens Reader in $lang...');
      app.navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const SummaryReaderScreen(bookId: 'sapiens')),
      );
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(SummaryReaderScreen), findsOneWidget);
      expect(find.textContaining('Offline mode'), findsNothing);
      expect(find.textContaining('Upgrade to Premium'), findsNothing);
      await capture('live_free_sapiens_read_$lang');

      app.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      debugPrint('  [Free] Opening sapiens Audio in $lang...');
      app.navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const BookDetailsScreen(bookId: 'sapiens')),
      );
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(find.byType(BookDetailsScreen), findsOneWidget);
      expect(find.textContaining('Unable to load book text'), findsNothing);
      await capture('live_free_sapiens_audio_$lang');

      app.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }

    // =========================================================================
    // TEST 5: HIDDEN / UNPUBLISHED LANGUAGE UNAVAILABILITY
    // =========================================================================
    debugPrint('\n--- TEST 5: Hidden / Unpublished Language Check ---');
    await tester.runAsync(() async {
      await AppLocator.auth.signOut();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await FirebaseAuth.instance.signInWithCustomToken(_primaryCustomToken);
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (AppLocator.auth.currentUser != null && AppLocator.auth.currentUser!.email == 'pkaramani@gmail.com') {
          break;
        }
      }
    });

    await tester.runAsync(() async {
      final books = await AppLocator.db.fetchBooks();
      debugPrint('Total production books loaded: ${books.length}');
      final booksWithHidden = books.where((b) => b.hiddenLanguages.isNotEmpty).toList();
      debugPrint('Books with hiddenLanguages in production: ${booksWithHidden.length}');
      for (final hb in booksWithHidden) {
        debugPrint('  -> Book ${hb.id} hidden languages: ${hb.hiddenLanguages}');
        for (final hLang in hb.hiddenLanguages) {
          try {
            await ProtectedTextService.hydrate(hb, hLang);
            fail('Production book ${hb.id} with hidden language $hLang should have thrown UnpublishedLanguageException');
          } on UnpublishedLanguageException catch (e) {
            expect(e.language, hLang);
            debugPrint('  ✓ Production book ${hb.id} hidden language $hLang correctly blocked: ${e.message}');
          }
        }
      }

      final atomic = books.firstWhere((b) => b.id == 'atomic_habits');
      final syntheticHiddenBook = Book.fromMap('atomic_hidden_test', {
        ...atomic.toMap(),
        'hiddenLanguages': ['es', 'de'],
      });
      try {
        await ProtectedTextService.hydrate(syntheticHiddenBook, 'es');
        fail('Should throw UnpublishedLanguageException for hidden language es');
      } on UnpublishedLanguageException catch (e) {
        expect(e.language, 'es');
        expect(e.message, 'Content in this language is currently unavailable.');
        debugPrint('✓ Hidden/unpublished language correctly blocked with message: ${e.message}');
      }

      // Also confirm unpublished book throws ContentUnavailableException
      final unpublishedBook = Book.fromMap('unpublished_test', {
        ...atomic.toMap(),
        'isPublished': false,
      });
      try {
        await ProtectedTextService.hydrate(unpublishedBook, 'en');
        fail('Should throw ContentUnavailableException for unpublished book');
      } on ContentUnavailableException catch (e) {
        expect(e.message, 'This title is not published.');
        debugPrint('✓ Unpublished book correctly blocked with message: ${e.message}');
      }
    });

    // Sign out at completion
    await tester.runAsync(() => AppLocator.auth.signOut());
    debugPrint('=== ALL 5 LIVE PHONE VERIFICATION SUITES PASSED! ===');
  });
}
