import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partwk/main.dart';
import 'package:partwk/core/theme/app_theme.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/core/services/family_service.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/features/profile/settings_screen.dart';

class FakeAudioService extends AudioService {
  @override bool get isPlaying => false;
  @override double get speed => 1.0;
  @override Duration get position => Duration.zero;
  @override Duration get duration => const Duration(minutes: 15);
  @override String? get currentBookId => null;
  @override String? get currentLangCode => 'en';
  @override String? get currentBookTitle => null;
  @override String? get currentCoverUrl => null;
  @override int get currentChapterIndex => 0;
  @override List<Map<String, dynamic>> get chapters => [];
  @override Duration? get sleepTimerRemaining => null;
  @override bool get isCurrentBookPremium => false;
  @override bool get isGuestRestricted => false;
  @override void clearGuestRestriction() {}
  @override Future<void> init() async {}
  @override Future<void> clearState() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthServiceTest extends AuthService {
  UserModel? _user;
  @override UserModel? get currentUser => _user;
  @override bool get isGuest => _user == null;
  void setUser(UserModel? u) => _user = u;
  @override
  Future<void> updateSelectedLanguage(String langCode) async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFamilyServiceTest extends FamilyService {
  MockFamilyServiceTest({this.statusResult, this.statusError});
  Map<String, dynamic>? statusResult;
  Object? statusError;
  int statusCallCount = 0;
  bool inviteCalled = false;
  String? invitedEmail;
  String? inviteLanguage;
  bool cancelCalled = false;
  bool removeCalled = false;
  bool leaveCalled = false;
  bool acceptCalled = false;

  @override
  Future<Map<String, dynamic>> status() async {
    statusCallCount++;
    if (statusError != null) throw statusError!;
    return statusResult ?? {};
  }

  @override
  Future<Map<String, dynamic>> invite(String email, {String? language}) async {
    inviteCalled = true;
    invitedEmail = email;
    inviteLanguage = language;
    return {'acceptedForDelivery': true};
  }

  @override
  Future<Map<String, dynamic>> cancel() async {
    cancelCalled = true;
    return {'status': 'cancelled'};
  }

  @override
  Future<Map<String, dynamic>> remove() async {
    removeCalled = true;
    return {'status': 'removed'};
  }

  @override
  Future<Map<String, dynamic>> leave() async {
    leaveCalled = true;
    return {'status': 'removed'};
  }

  @override
  Future<Map<String, dynamic>> accept() async {
    acceptCalled = true;
    return {'status': 'active'};
  }
}

UserModel makeUser({
  required String id,
  required String email,
  String status = 'premium',
  bool hasFamilyPremium = false,
}) {
  return UserModel(
    id: id,
    name: 'Test User',
    email: email,
    selectedLanguage: 'en',
    interests: const ['productivity'],
    learningGoals: const ['15_mins'],
    subscriptionStatus: status,
    hasFamilyPremium: hasFamilyPremium,
    familyMembers: const [],
    savedBooks: const [],
    completedBooks: const [],
    likedBooks: const [],
    listeningProgress: const {},
    readingProgress: const {},
    streakCount: 1,
    lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
    createdAt: DateTime.now(),
  );
}

Widget buildTestScreen(Locale locale) {
  final langState = AppLanguageState();
  langState.setLanguage(locale.languageCode);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguageState>.value(value: langState),
      ChangeNotifierProvider<AppThemeProvider>(create: (_) => AppThemeProvider()),
      ChangeNotifierProvider<AudioService>.value(value: AppLocator.audio),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ku'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
        FallbackWidgetsLocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  late MockAuthServiceTest mockAuth;
  late FakeAudioService mockAudio;
  late MockFamilyServiceTest mockFamily;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockAuth = MockAuthServiceTest();
    mockAudio = FakeAudioService();
    mockFamily = MockFamilyServiceTest();

    AppLocator.auth = mockAuth;
    AppLocator.audio = mockAudio;
    AppLocator.family = mockFamily;
  });

  group('Family Sharing Settings UI Tests', () {
    testWidgets('State 1: Primary with Active Member shows email and locked note, hides remove button and invite input', (tester) async {
      mockAuth.setUser(makeUser(id: 'primary_1', email: 'primary@example.com', status: 'premium'));
      mockFamily.statusResult = {
        'membership': null,
        'family': {
          'ownerUid': 'primary_1',
          'memberUid': 'member_2',
          'memberEmail': 'linked@example.com',
        },
        'entitlement': {
          'status': 'active',
          'source': 'store',
        },
      };

      await tester.pumpWidget(buildTestScreen(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('1 of 1 Active'), findsOneWidget);
      expect(find.text('linked@example.com'), findsOneWidget);
      // Remove button is removed in favor of permanent lock support notice
      expect(find.text('Remove Member'), findsNothing);
      expect(find.textContaining('To change this family member, please contact Partwk Support at'), findsOneWidget);
      expect(find.text('sharing@partwk.com'), findsOneWidget);
      // Ensure email text field is completely absent
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Invite Family Member'), findsNothing);
    });

    testWidgets('State 2: Primary with Pending Invite shows invited email and locked note, hides cancel button and input', (tester) async {
      mockAuth.setUser(makeUser(id: 'primary_1', email: 'primary@example.com', status: 'premium'));
      mockFamily.statusResult = {
        'membership': null,
        'family': {
          'ownerUid': 'primary_1',
          'invitation': {
            'recipientUid': null,
            'recipientEmail': 'pending@example.com',
          },
        },
        'entitlement': {
          'status': 'active',
          'source': 'store',
        },
      };

      await tester.pumpWidget(buildTestScreen(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('1 of 1 Reserved'), findsOneWidget);
      expect(find.text('pending@example.com'), findsOneWidget);
      // Cancel button is removed in favor of permanent lock support notice
      expect(find.text('Cancel Invitation'), findsNothing);
      expect(find.textContaining('To change this family member, please contact Partwk Support at'), findsOneWidget);
      expect(find.text('sharing@partwk.com'), findsOneWidget);
      // Ensure email text field is completely absent
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('State 3: Primary with Empty Slot shows email field and Invite button', (tester) async {
      mockAuth.setUser(makeUser(id: 'primary_1', email: 'primary@example.com', status: 'premium'));
      mockFamily.statusResult = {
        'membership': null,
        'family': {
          'ownerUid': 'primary_1',
        },
        'entitlement': {
          'status': 'active',
          'source': 'store',
        },
      };

      await tester.pumpWidget(buildTestScreen(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Invite family member'), findsOneWidget);

      // Typing invalid email keeps button disabled or shows validation
      await tester.enterText(find.byType(TextField), 'notanemail');
      await tester.pumpAndSettle();

      // Enter valid email enables button
      await tester.enterText(find.byType(TextField), 'recipient@example.com');
      await tester.pumpAndSettle();

      final inviteBtn = find.text('Invite family member');
      await tester.ensureVisible(inviteBtn);
      await tester.tap(inviteBtn);
      await tester.pump();

      expect(mockFamily.inviteCalled, isTrue);
      expect(mockFamily.invitedEmail, 'recipient@example.com');
      expect(mockFamily.inviteLanguage, 'en');
    });

    testWidgets('State 4: Linked Member shows Premium through Family Sharing and Leave button only', (tester) async {
      mockAuth.setUser(makeUser(id: 'member_2', email: 'linked@example.com', status: 'free', hasFamilyPremium: true));
      mockFamily.statusResult = {
        'membership': {
          'ownerUid': 'primary_1',
          'memberUid': 'member_2',
          'state': 'active',
        },
        'family': null,
        'entitlement': {
          'status': 'active',
          'source': 'family',
          'ownerUid': 'primary_1',
        },
      };

      await tester.pumpWidget(buildTestScreen(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Premium through Family Sharing'), findsWidgets);
      expect(find.text('Leave Family Plan'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Invite family member'), findsNothing);
    });

    testWidgets('State 5: User with Received Pending Invite shows Accept Invitation button', (tester) async {
      mockAuth.setUser(makeUser(id: 'invited_user', email: 'invited@example.com', status: 'free'));
      mockFamily.statusResult = {
        'membership': {
          'ownerUid': 'primary_1',
          'memberUid': 'invited_user',
          'state': 'pending',
        },
        'family': null,
        'entitlement': {
          'status': 'inactive',
          'source': 'none',
        },
      };

      await tester.pumpWidget(buildTestScreen(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('You Have a Family Invitation'), findsOneWidget);
      expect(find.text('Accept Invitation'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('State 6: Free / expired subscriber shows upgrade prompt and button', (tester) async {
      mockAuth.setUser(makeUser(id: 'free_user', email: 'free@example.com', status: 'free'));
      mockFamily.statusResult = {
        'membership': null,
        'family': null,
        'entitlement': {
          'status': 'inactive',
          'source': 'none',
        },
      };

      await tester.pumpWidget(buildTestScreen(const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Explore Premium Plans'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Localisation EN, KU, AR renders correct translations and directionality', (tester) async {
      mockAuth.setUser(makeUser(id: 'primary_1', email: 'primary@example.com', status: 'premium'));
      mockFamily.statusResult = {
        'membership': null,
        'family': {'ownerUid': 'primary_1', 'memberUid': 'm2', 'memberEmail': 'ch@gmail.com'},
        'entitlement': {'status': 'active', 'source': 'store'},
      };

      // Kurdish Sorani
      await tester.pumpWidget(buildTestScreen(const Locale('ku')));
      await tester.pumpAndSettle();
      expect(find.text('١ لە ١ چالاکە'), findsOneWidget);
      expect(find.text('سڕینەوەی ئەندام'), findsNothing);
      expect(find.textContaining('بۆ گۆڕینی ئەم ئەندامەی خێزانە، تکایە پەیوەندی بە پشتگیری پەرتوک بکە لە:'), findsOneWidget);
      expect(find.text('sharing@partwk.com'), findsOneWidget);

      // Arabic
      await tester.pumpWidget(buildTestScreen(const Locale('ar')));
      await tester.pumpAndSettle();
      expect(find.text('نشط 1 من 1'), findsOneWidget);
      expect(find.text('إزالة العضو'), findsNothing);
      expect(find.textContaining('لتغيير فرد العائلة هذا، يرجى التواصل مع دعم Partwk عبر:'), findsOneWidget);
      expect(find.text('sharing@partwk.com'), findsOneWidget);
    });

    testWidgets('App lifecycle resumed event triggers status refresh', (tester) async {
      mockAuth.setUser(makeUser(id: 'primary_1', email: 'primary@example.com', status: 'premium'));
      mockFamily.statusResult = {
        'membership': null,
        'family': {'ownerUid': 'primary_1'},
        'entitlement': {'status': 'active', 'source': 'store'},
      };

      await tester.pumpWidget(buildTestScreen(const Locale('en')));
      await tester.pumpAndSettle();

      final initialCount = mockFamily.statusCallCount;
      expect(initialCount, greaterThanOrEqualTo(1));

      // Invoke didChangeAppLifecycleState with resumed on the observer
      final state = tester.state(find.byType(SettingsScreen)) as WidgetsBindingObserver;
      state.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(mockFamily.statusCallCount, greaterThan(initialCount));
    });
  });
}
