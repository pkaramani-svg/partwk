import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:integration_test/integration_test.dart';
import 'package:partwk/main.dart' as app;
import 'package:partwk/core/services/database_service.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/models/book.dart';

class GatedBooks extends MockDatabaseService {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<Book>> fetchBooks() async {
    if (!entered.isCompleted) entered.complete();
    await release.future;
    return [];
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('progress stays with its owner across active playback account switches', (tester) async {
    await tester.runAsync(app.main);
    for (var i=0; i<12; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds:250)));
      await tester.pump(const Duration(milliseconds:250));
    }
    final messages = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
      previousDebugPrint(message, wrapWidth: wrapWidth);
    };
    await tester.runAsync(() async {
      await AppLocator.auth.signOut();
      await AppLocator.auth.signInWithEmailAndPassword('primary@test.invalid','Test-only-123!');
      final previous = AppLocator.db;
      final gate = GatedBooks();
      AppLocator.db = gate;
      try {
        final pending = AppLocator.auth.updateListeningProgress('race-fixture','en',0,3);
        await gate.entered.future.timeout(const Duration(seconds:20));
        await AppLocator.auth.signOut();
        gate.release.complete();
        await pending;
      } finally {
        if (!gate.release.isCompleted) gate.release.complete();
        AppLocator.db = previous;
      }
    });
    expect(messages.where((line) => line.contains('Error updating listening progress')), isEmpty);

    Future<void> waitForPlayer() async {
      for (var i=0; i<16; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds:250)));
        await tester.pump(const Duration(milliseconds:250));
      }
    }
    await tester.runAsync(() => AppLocator.auth.signInWithEmailAndPassword('primary@test.invalid','Test-only-123!'));
    final books = (await tester.runAsync(() => AppLocator.db.fetchBooks()))!;
    final premium = books.firstWhere((book) => book.id == 'workflow-premium');
    final free = books.firstWhere((book) => book.id == 'workflow-free');
    AppLocator.audio.play(premium.id, 'en', premium.getTitle('en'), '', '', premium.getChapterSummaries('en'));
    await waitForPlayer();
    expect(AppLocator.audio.isPlaying, isTrue);
    await tester.runAsync(() => AppLocator.auth.signOut());
    expect(AppLocator.audio.currentBookId, isNull);
    await tester.runAsync(() => AppLocator.auth.signInWithEmailAndPassword('family@test.invalid','Test-only-123!'));
    final familyBefore = (await tester.runAsync(() => FirebaseFirestore.instance.doc('users/workflow-family').get(const GetOptions(source:Source.server))))!.data()!;
    expect((familyBefore['listeningProgress'] as Map? ?? {}).containsKey('workflow-premium_en'), isFalse);
    AppLocator.audio.play(free.id, 'en', free.getTitle('en'), '', '', free.getChapterSummaries('en'));
    await waitForPlayer();
    expect(AppLocator.audio.isPlaying, isTrue);
    await tester.runAsync(() => AppLocator.auth.signOut());
    expect(AppLocator.audio.currentBookId, isNull);
    await waitForPlayer();
    expect(AppLocator.audio.currentBookId, isNull);
    await tester.runAsync(() => AppLocator.auth.signInWithEmailAndPassword('family@test.invalid','Test-only-123!'));
    final familyAfter = (await tester.runAsync(() => FirebaseFirestore.instance.doc('users/workflow-family').get(const GetOptions(source:Source.server))))!.data()!;
    expect((familyAfter['listeningProgress'] as Map).containsKey('workflow-free_en'), isTrue);
    expect((familyAfter['listeningProgress'] as Map).containsKey('workflow-premium_en'), isFalse);
    await tester.runAsync(() => AppLocator.auth.signOut());
    await tester.runAsync(() => AppLocator.auth.signInWithEmailAndPassword('primary@test.invalid','Test-only-123!'));
    final primaryAfter = (await tester.runAsync(() => FirebaseFirestore.instance.doc('users/workflow-primary').get(const GetOptions(source:Source.server))))!.data()!;
    expect((primaryAfter['listeningProgress'] as Map).containsKey('workflow-premium_en'), isTrue);
    expect((primaryAfter['listeningProgress'] as Map).containsKey('workflow-free_en'), isFalse);
    await tester.runAsync(() => AppLocator.auth.signOut());
    expect(messages.where((line) => line.contains('Error updating listening progress') || line.contains('Error saving audio state')), isEmpty);
    debugPrint = previousDebugPrint;
  });
}
