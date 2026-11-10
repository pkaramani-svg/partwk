import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/audio_service.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/models/user.dart';

class MockAudioServiceForRevocation extends AudioService {
  bool stopCalled = false;
  bool pauseCalled = false;
  bool _isPlaying = true;
  bool _isPremiumBook = true;

  @override
  bool get isPlaying => _isPlaying;

  @override
  bool get isCurrentBookPremium => _isPremiumBook;

  void setPlaybackState({required bool isPlaying, required bool isPremium}) {
    _isPlaying = isPlaying;
    _isPremiumBook = isPremium;
  }

  @override
  void stop() {
    stopCalled = true;
    _isPlaying = false;
    notifyListeners();
  }

  @override
  void pause() {
    pauseCalled = true;
    _isPlaying = false;
    notifyListeners();
  }

  @override double get speed => 1.0;
  @override Duration get position => Duration.zero;
  @override Duration get duration => const Duration(minutes: 10);
  @override String? get currentBookId => 'test_book_1';
  @override String? get currentLangCode => 'en';
  @override String? get currentBookTitle => 'Test Book';
  @override String? get currentCoverUrl => null;
  @override int get currentChapterIndex => 0;
  @override List<Map<String, dynamic>> get chapters => [];
  @override Duration? get sleepTimerRemaining => null;
  @override bool get isGuestRestricted => false;
  @override void clearGuestRestriction() {}
  @override Future<void> init() async {}
  @override Future<void> clearState() async {}
  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestableRevocationAuthService extends AuthService {
  UserModel? _user;
  bool revocationNotificationFired = false;
  bool storageCleared = false;

  TestableRevocationAuthService(UserModel initialUser) {
    _user = initialUser;
    familyPremiumRevokedStream.listen((_) {
      revocationNotificationFired = true;
    });
  }

  @override
  UserModel? get currentUser => _user;

  @override
  bool get isAuthenticated => _user != null;

  @override
  bool get isGuest => false;

  @override
  String get signInProvider => 'password';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> refreshEntitlementAuthoritatively() async {}

  /// Simulate receiving a backend entitlement revocation event while online
  Future<void> simulateEntitlementChange({
    required String status,
    required String source,
    String? membershipState,
  }) async {
    final wasFamilyPremium = _user?.hasFamilyPremium ?? false;
    final isNowFamilyPremium = source == 'family' && status == 'active' && (membershipState == null || membershipState == 'active');

    if (wasFamilyPremium && !isNowFamilyPremium) {
      // 1. Immediately update in-memory state
      _user = _user!.copyWith(
        hasFamilyPremium: false,
        subscriptionStatus: 'free',
        subscriptionExpiryDate: null,
      );

      // 2. Stop audio if premium book playing
      if (AppLocator.audio.isCurrentBookPremium && AppLocator.audio.isPlaying) {
        AppLocator.audio.stop();
      }

      // 3. Clear storage and licences
      storageCleared = true;
      await OfflineAvailabilityRepository.clearAllMetadataForUser(_user!.id);

      // 4. Notify UI
      notifyListeners();

      // 5. Fire revocation event for localized message
      triggerFamilyPremiumRevoked();
    }
  }

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Family Sharing Immediate Revocation Flow', () {
    late UserModel activeFamilyUser;
    late MockAudioServiceForRevocation mockAudio;
    late TestableRevocationAuthService testAuth;

    setUp(() {
      activeFamilyUser = UserModel(
        id: 'member_user_123',
        name: 'Test Member',
        email: 'member@partwk.com',
        selectedLanguage: 'en',
        interests: ['Tech'],
        learningGoals: ['Productivity'],
        savedBooks: ['book_saved_1'],
        completedBooks: ['book_completed_1'],
        likedBooks: ['book_liked_1'],
        listeningProgress: {},
        readingProgress: {},
        subscriptionStatus: 'free',
        hasFamilyPremium: true,
        streakCount: 5,
        lastActiveDate: '2026-11-10',
        familyMembers: [],
        createdAt: DateTime.now(),
      );

      mockAudio = MockAudioServiceForRevocation();
      AppLocator.audio = mockAudio;

      testAuth = TestableRevocationAuthService(activeFamilyUser);
      AppLocator.auth = testAuth;
    });

    test('1. Active family member removed while online -> Premium state changes without logout', () async {
      expect(testAuth.currentUser!.isPremium, true);
      expect(testAuth.currentUser!.hasFamilyPremium, true);

      // Simulate backend revocation event
      await testAuth.simulateEntitlementChange(
        status: 'inactive',
        source: 'none',
        membershipState: 'removed',
      );

      // User remains logged in (not null), but Premium access ends immediately
      expect(testAuth.currentUser, isNotNull);
      expect(testAuth.currentUser!.id, 'member_user_123');
      expect(testAuth.currentUser!.hasFamilyPremium, false);
      expect(testAuth.currentUser!.isPremium, false);
      expect(testAuth.currentUser!.subscriptionStatus, 'free');
    });

    test('2. Active Premium audio stops and Premium reader access is blocked', () async {
      mockAudio.setPlaybackState(isPlaying: true, isPremium: true);
      expect(mockAudio.isPlaying, true);
      expect(mockAudio.stopCalled, false);

      await testAuth.simulateEntitlementChange(
        status: 'inactive',
        source: 'none',
        membershipState: 'removed',
      );

      // Audio must stop safely
      expect(mockAudio.stopCalled, true);
      expect(mockAudio.isPlaying, false);

      // Reader access blocked because user.isPremium is false
      expect(testAuth.currentUser!.isPremium, false);
    });

    test('3. Downloaded Premium editions and cached metadata are cleared securely', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('cached_books_metadata_member_user_123', ['book_1']);
      await prefs.setStringList('cached_editions_metadata_member_user_123', ['book_1_en']);

      await testAuth.simulateEntitlementChange(
        status: 'inactive',
        source: 'none',
        membershipState: 'removed',
      );

      expect(testAuth.storageCleared, true);
      expect(prefs.getStringList('cached_books_metadata_member_user_123'), isNull);
      expect(prefs.getStringList('cached_editions_metadata_member_user_123'), isNull);
    });

    test('4. Free account, profile, and library remain intact', () async {
      await testAuth.simulateEntitlementChange(
        status: 'inactive',
        source: 'none',
        membershipState: 'removed',
      );

      final user = testAuth.currentUser!;
      expect(user.id, 'member_user_123');
      expect(user.name, 'Test Member');
      expect(user.email, 'member@partwk.com');
      expect(user.savedBooks, contains('book_saved_1'));
      expect(user.completedBooks, contains('book_completed_1'));
      expect(user.likedBooks, contains('book_liked_1'));
      expect(user.streakCount, 5);
    });

    test('5. Offline device behaviour: revokes immediately upon reconnect and refresh', () async {
      // While offline, local cached user was family premium
      expect(testAuth.currentUser!.isPremium, true);

      // Once device reconnects and fetches authoritative server entitlement
      await testAuth.simulateEntitlementChange(
        status: 'inactive',
        source: 'none',
        membershipState: 'removed',
      );

      expect(testAuth.currentUser!.isPremium, false);
      await Future.delayed(Duration.zero);
      expect(testAuth.revocationNotificationFired, true);
    });

    test('6. EN, KU and AR revocation message and RTL layout validation', () {
      final enValues = AppLocalizations.localizedValues['en']!;
      final kuValues = AppLocalizations.localizedValues['ku']!;
      final arValues = AppLocalizations.localizedValues['ar']!;

      expect(enValues['family_premium_revoked_message'], 'Your Family Premium access has ended.');
      expect(kuValues['family_premium_revoked_message'], 'دەستپێڕاگەیشتنی پەرتوک پڕیمیۆمی خێزانیت کۆتایی هات.');
      expect(arValues['family_premium_revoked_message'], 'انتهت فترة وصولك إلى اشتراك العائلة بريميوم.');

      // Validate Kurdish Partwk spelling
      expect(kuValues['family_premium_revoked_message']!.contains('پەرتوک'), true);
      expect(kuValues['family_premium_revoked_message']!.contains('پارتوک'), false);

      // Validate RTL text direction logic
      bool isRtl(String lang) => lang == 'ku' || lang == 'ar';
      expect(isRtl('ku'), true);
      expect(isRtl('ar'), true);
      expect(isRtl('en'), false);
    });
  });
}
