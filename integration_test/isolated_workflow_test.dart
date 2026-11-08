import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:partwk/main.dart' as app;
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/protected_text_service.dart';
import 'package:partwk/core/services/download_manager.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/features/book/summary_reader_screen.dart';
import 'package:partwk/features/audio/audio_player_screen.dart';

Future<void> settleNetwork(WidgetTester tester) async {
  for (var i = 0; i < 16; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('isolated free, primary, family, audio and offline workflows', (tester) async {
    await tester.runAsync(app.main);
    await settleNetwork(tester);
    expect(app.navigatorKey.currentState, isNotNull);

    Future<void> login(String name) async {
      await tester.runAsync(() async {
        await AppLocator.auth.signOut();
        await AppLocator.auth.signInWithEmailAndPassword('$name@test.invalid', 'Test-only-123!');
      });
      await settleNetwork(tester);
      await settleNetwork(tester);
    }

    Future<void> showReader(String id) async {
      app.navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => SummaryReaderScreen(bookId: id)));
      await settleNetwork(tester);
      await settleNetwork(tester);
      if (find.text('This is a complete synthetic chapter for local reading and listening.').evaluate().isEmpty) {
        debugPrint('Reader diagnostic: book=$id user=${AppLocator.auth.currentUser?.id} '
            'reader=${find.byType(SummaryReaderScreen).evaluate().length} '
            'offlineMessage=${find.text('Connect to the internet to download or stream this title.').evaluate().length}');
        final books = await tester.runAsync(() => AppLocator.db.fetchBooks());
        final book = books!.firstWhere((item) => item.id == id);
        debugPrint('Reader diagnostic: premium=${book.isPremium} languages=${book.chapterSummaries.keys.toList()} '
            'downloaded=${await tester.runAsync(() => DownloadManager.isBookDownloaded(id))}');
      }
      expect(find.text('This is a complete synthetic chapter for local reading and listening.'), findsOneWidget);
      app.navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
    }

    Future<void> verifyPersonalProgress(String uid, String status) async {
      await tester.runAsync(() => AppLocator.auth.updateListeningProgress('profile-fixture', 'en', 0, 7));
      final snapshot = await tester.runAsync(() => FirebaseFirestore.instance
          .doc('users/$uid').get(const GetOptions(source: Source.server)));
      final data = snapshot!.data()!;
      expect(data['listeningProgress']['profile-fixture_en']['positionSeconds'], 7);
      expect(data['subscriptionStatus'], status);
      expect(data['hasFamilyPremium'], false);
      expect(data.containsKey('subscriptionExpiryDate'), isFalse);
      debugPrint('Profile workflow: $uid progress persisted without changing protected fields.');
    }

    await login('free');
    await showReader('workflow-free');
    var books = await tester.runAsync(() => AppLocator.db.fetchBooks());
    final freeBook = books!.firstWhere((book) => book.id == 'workflow-free');
    AppLocator.audio.play(freeBook.id, 'en', freeBook.getTitle('en'), '', '', freeBook.getChapterSummaries('en'));
    await settleNetwork(tester);
    expect(AppLocator.audio.currentBookId, 'workflow-free');
    expect(AppLocator.audio.isPlaying, isTrue);
    await tester.runAsync(() async => AppLocator.audio.stop());

    await login('primary');
    await showReader('workflow-premium');
    await verifyPersonalProgress('workflow-primary', 'premium');
    debugPrint('Reader workflow: primary Premium chapter displayed.');
    await login('family');
    await showReader('workflow-premium');
    await verifyPersonalProgress('workflow-family', 'free');
    debugPrint('Reader workflow: family Premium chapter displayed.');
    await login('primary');
    books = await tester.runAsync(() => AppLocator.db.fetchBooks());
    var premium = books!.firstWhere((book) => book.id == 'workflow-premium');
    premium = (await tester.runAsync(() => ProtectedTextService.hydrate(premium, 'en')))!;
    expect(premium.getChapterSummaries('en').first['content'], contains('synthetic chapter'));
    AppLocator.audio.play(premium.id, 'en', premium.getTitle('en'), '', '', premium.getChapterSummaries('en'));
    await settleNetwork(tester);
    expect(AppLocator.audio.isPlaying, isTrue);
    app.navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => AudioPlayerScreen(
      bookId: premium.id, langCode: 'en', bookTitle: premium.getTitle('en'), coverUrl: '',
      globalAudioUrl: '', chapters: premium.getChapterSummaries('en'), bookDurationSecs: 16,
    )));
    await settleNetwork(tester);
    for (var i = 0; i < 6 && find.text('Summary Completed!').evaluate().isEmpty; i++) {
      await settleNetwork(tester);
    }
    expect(find.text('Summary Completed!'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Summary Completed!'), findsNothing);
    debugPrint('Audio workflow: completion popup dismissed using Continue.');
    final toggle = find.text('Show text');
    expect(toggle, findsOneWidget);
    await tester.tap(toggle);
    await settleNetwork(tester);
    expect(find.textContaining('This is a complete synthetic chapter.'), findsWidgets);
    debugPrint('Audio workflow: text panel displayed.');
    app.navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.runAsync(() async => AppLocator.audio.stop());

    final downloaded = await tester.runAsync(() => DownloadManager().downloadBook(premium, 'en', (_) {}));
    expect(downloaded, isTrue);
    debugPrint('Offline workflow: encrypted book download completed.');
    var reopened = await tester.runAsync(() => DownloadManager.loadBookContent(premium));
    expect(reopened!.getChapterSummaries('en').first['content'], contains('synthetic chapter'));
    NetworkGuard.mockConnectionStatus = false;
    reopened = await tester.runAsync(() => DownloadManager.loadBookContent(premium));
    expect(reopened!.getChapterSummaries('en').first['content'], contains('synthetic chapter'));
    debugPrint('Offline workflow: downloaded text reopened with simulated offline status.');
    NetworkGuard.mockConnectionStatus = null;

  });
}
