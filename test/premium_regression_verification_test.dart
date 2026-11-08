import 'package:flutter_test/flutter_test.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/services/protected_text_service.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/user.dart';

class MockAuthServiceForTest extends MockAuthService {
  UserModel? _currentUser;
  bool _isGuest = false;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null && !_isGuest;

  @override
  bool get isGuest => _isGuest;

  void setLoggedInUser(UserModel? user, {bool guest = false}) {
    _currentUser = user;
    _isGuest = guest;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {}
  @override
  Future<void> registerWithEmailAndPassword(String name, String email, String password) async {}
  @override
  Future<void> signOut() async {
    _currentUser = null;
    _isGuest = false;
    notifyListeners();
  }
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInWithApple() async {}
  @override
  Future<void> checkAndUnlockAchievements() async {}
  @override
  Future<void> signInAsGuest() async {
    _isGuest = true;
    notifyListeners();
  }
  @override
  Future<void> updateSelectedLanguage(String langCode) async {}
  @override
  Future<void> updateInterests(List<String> interests) async {}
  @override
  Future<void> updateGoals(List<String> goals) async {}
  @override
  Future<void> addSavedBook(String bookId) async {}
  @override
  Future<void> removeSavedBook(String bookId) async {}
  @override
  Future<void> addLikedBook(String bookId) async {}
  @override
  Future<void> removeLikedBook(String bookId) async {}
  @override
  Future<void> addCompletedBook(String bookId, {String source = 'automatic', DateTime? completedAt}) async {}
  @override
  Future<void> removeCompletedBook(String bookId) async {}
  @override
  Future<void> linkFamilyMember(String email) async {}
  @override
  Future<void> upgradeToPremium() async {}
  @override
  Future<void> updateListeningProgress(String bookId, String langCode, int chapterIndex, int positionSeconds, {int accumulatedSecondHalfSeconds = 0, bool localOnly = false, String? expectedUserId}) async {}
  @override
  Future<void> recordActivity() async {}
  @override
  Future<void> addLearningTime(int seconds) async {}
  @override
  Future<void> updatePresence({required String screen, String? bookTitle, String? bookId, String? activityType}) async {}
  @override
  Future<void> updateProfilePicture(String url) async {}
  @override
  Future<void> setOnlineStatus(bool isOnline) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthServiceForTest mockAuth;

  // Production User Fixtures via fromMap
  final primaryPremiumUser = UserModel.fromMap('9ZpveoOzAednE7Z3J5viC3hPfgC3', {
    'email': 'pkaramani@gmail.com',
    'name': 'Peshraw Karamani',
    'selectedLanguage': 'en',
    'subscriptionStatus': 'premium',
    'hasFamilyPremium': false,
    'familyMembers': ['chrpa1997@gmail.com'],
  });

  final linkedFamilyUser = UserModel.fromMap('gXpGkXVs6ZbwJnLaLDGNqhkc6ak2', {
    'email': 'chrpa1997@gmail.com',
    'name': 'Chrpa',
    'selectedLanguage': 'ku',
    'subscriptionStatus': 'free',
    'hasFamilyPremium': true,
    'familyMembers': [],
  });

  final freeUser = UserModel.fromMap('bII7HzmD9BONLa6v8n1yv0bw7Yx1', {
    'email': 'pk@karamani.com',
    'name': 'PK Free',
    'selectedLanguage': 'en',
    'subscriptionStatus': 'free',
    'hasFamilyPremium': false,
    'familyMembers': [],
  });

  // Production Book Fixtures via fromMap
  // 1. Free Book: sapiens (isPremium: false)
  final freeBookSapiens = Book.fromMap('sapiens', {
    'title': {'en': 'Sapiens', 'ku': 'سەیپێنس', 'ar': 'العاقل'},
    'author': {'en': 'Yuval Noah Harari', 'ku': 'یوڤاڵ نوح هەراری', 'ar': 'يوفال نوح هراري'},
    'coverImageUrl': 'https://partwk.com/covers/sapiens.jpg',
    'isPremium': false,
    'isPublished': true,
    'hiddenLanguages': [],
    'chapterSummaries': {
      'en': [
        {'title': 'Introduction', 'content': 'Full English introduction to Sapiens...', 'segments': []},
        {'title': 'Chapter 1', 'content': 'An Animal of No Significance...', 'segments': []},
      ],
      'ku': [
        {'title': 'پێشەکی', 'content': 'پێشەکی کوردی بۆ سەیپێنس...', 'segments': []},
        {'title': 'بەشی ١', 'content': 'گیانلەبەرێکی بێ بایەخ...', 'segments': []},
      ],
      'ar': [
        {'title': 'المقدمة', 'content': 'مقدمة كتاب العاقل باللغة العربية...', 'segments': []},
        {'title': 'الفصل الأول', 'content': 'حيوان لا أهمية له...', 'segments': []},
      ],
    },
    'audioUrl': {
      'en': 'https://partwk.com/audio/sapiens_en.mp3',
      'ku': 'https://partwk.com/audio/sapiens_ku.mp3',
      'ar': 'https://partwk.com/audio/sapiens_ar.mp3',
    },
    'duration': 3600,
  });

  // 2. Published Premium Book: atomic_habits (isPremium: true)
  final premiumBookAtomicHabits = Book.fromMap('atomic_habits', {
    'title': {'en': 'Atomic Habits', 'ku': 'خووە بچووکەکان', 'ar': 'العادات الذرية'},
    'author': {'en': 'James Clear', 'ku': 'جەیمس کلیر', 'ar': 'جيمس كلير'},
    'coverImageUrl': 'https://partwk.com/covers/atomic_habits.jpg',
    'isPremium': true,
    'isPublished': true,
    'hiddenLanguages': [],
    'chapterSummaries': {
      'en': [
        {'title': 'The Fundamentals', 'content': 'Tiny Changes, Remarkable Results...', 'segments': []},
        {'title': '1st Law', 'content': 'Make it Obvious...', 'segments': []},
      ],
      'ku': [
        {'title': 'پێشەکی', 'content': 'گۆڕانکارییە بچووکەکان، ئەنجامە گەورەکان...', 'segments': []},
        {'title': 'یاسای یەکەم', 'content': 'ئاشکرای بکە...', 'segments': []},
      ],
      'ar': [
        {'title': 'المقدمة', 'content': 'تغييرات صغيرة، نتائج باهرة...', 'segments': []},
        {'title': 'القانون الأول', 'content': 'اجعلها واضحة...', 'segments': []},
      ],
    },
    'audioUrl': {
      'en': 'https://partwk.com/audio/atomic_en.mp3',
      'ku': 'https://partwk.com/audio/atomic_ku.mp3',
      'ar': 'https://partwk.com/audio/atomic_ar.mp3',
    },
    'duration': 4200,
  });

  // 3. Premium Book with Hidden Language
  final bookWithHiddenLanguage = Book.fromMap('thinking_fast_slow', {
    'title': {'en': 'Thinking, Fast and Slow'},
    'author': {'en': 'Daniel Kahneman'},
    'coverImageUrl': 'https://partwk.com/covers/thinking.jpg',
    'isPremium': true,
    'isPublished': true,
    'hiddenLanguages': ['ar'], // Arabic is explicitly hidden/unpublished
    'chapterSummaries': {
      'en': [{'title': 'Two Systems', 'content': 'System 1 and System 2...', 'segments': []}],
      'ar': [{'title': 'نظامان', 'content': 'النظام الأول والنظام الثاني...', 'segments': []}],
    },
    'audioUrl': {'en': 'https://partwk.com/audio/thinking_en.mp3'},
    'duration': 3000,
  });

  setUp(() {
    mockAuth = MockAuthServiceForTest();
    AppLocator.auth = mockAuth;
    NetworkGuard.mockConnectionStatus = true;
  });

  tearDown(() {
    NetworkGuard.mockConnectionStatus = null;
  });

  group('Production Premium Access Regression Verification', () {
    test('1. Valid Primary Premium user can read and play Premium book across all languages (en, ku, ar)', () async {
      mockAuth.setLoggedInUser(primaryPremiumUser);
      expect(primaryPremiumUser.isPremium, isTrue);

      for (final lang in ['en', 'ku', 'ar']) {
        final hydrated = await ProtectedTextService.hydrate(premiumBookAtomicHabits, lang);
        expect(hydrated, isNotNull);
        final chapters = hydrated.getChapterSummaries(lang);
        expect(chapters.isNotEmpty, isTrue);
        expect(chapters[0]['content'], isNotEmpty);
      }
    });

    test('2. Linked Family Member retains entitlement and can read and play Premium book across all languages (en, ku, ar)', () async {
      mockAuth.setLoggedInUser(linkedFamilyUser);
      expect(linkedFamilyUser.hasFamilyPremium, isTrue);
      expect(linkedFamilyUser.isPremium, isTrue);

      for (final lang in ['en', 'ku', 'ar']) {
        final hydrated = await ProtectedTextService.hydrate(premiumBookAtomicHabits, lang);
        expect(hydrated, isNotNull);
        final chapters = hydrated.getChapterSummaries(lang);
        expect(chapters.isNotEmpty, isTrue);
        expect(chapters[0]['content'], isNotEmpty);
      }
    });

    test('3. Free user is strictly denied Premium book content with clear upgrade permission exception (not offline error)', () async {
      mockAuth.setLoggedInUser(freeUser);
      expect(freeUser.isPremium, isFalse);

      for (final lang in ['en', 'ku', 'ar']) {
        expect(
          () => ProtectedTextService.hydrate(premiumBookAtomicHabits, lang),
          throwsA(isA<ContentPermissionDeniedException>()),
        );
      }
    });

    test('4. Unauthenticated / Guest caller is denied Premium book content with unauthenticated exception', () async {
      mockAuth.setLoggedInUser(null);
      expect(
        () => ProtectedTextService.hydrate(premiumBookAtomicHabits, 'en'),
        throwsA(isA<ContentUnauthenticatedException>()),
      );

      mockAuth.setLoggedInUser(freeUser, guest: true);
      expect(
        () => ProtectedTextService.hydrate(premiumBookAtomicHabits, 'en'),
        throwsA(isA<ContentUnauthenticatedException>()),
      );
    });

    test('5. Non-Premium book (sapiens) remains fully free and accessible to Free, Family, and Guest users across en, ku, ar', () async {
      // Free user
      mockAuth.setLoggedInUser(freeUser);
      for (final lang in ['en', 'ku', 'ar']) {
        final book = await ProtectedTextService.hydrate(freeBookSapiens, lang);
        expect(book.getChapterSummaries(lang).isNotEmpty, isTrue);
        expect(book.getChapterSummaries(lang)[0]['content'], isNotEmpty);
      }

      // Guest user
      mockAuth.setLoggedInUser(null);
      for (final lang in ['en', 'ku', 'ar']) {
        final book = await ProtectedTextService.hydrate(freeBookSapiens, lang);
        expect(book.getChapterSummaries(lang).isNotEmpty, isTrue);
      }

      // Primary Premium user
      mockAuth.setLoggedInUser(primaryPremiumUser);
      for (final lang in ['en', 'ku', 'ar']) {
        final book = await ProtectedTextService.hydrate(freeBookSapiens, lang);
        expect(book.getChapterSummaries(lang).isNotEmpty, isTrue);
      }
    });

    test('6. Hidden/unpublished language content remains strictly unavailable and throws UnpublishedLanguageException', () async {
      mockAuth.setLoggedInUser(primaryPremiumUser);

      // English is published
      final enBook = await ProtectedTextService.hydrate(bookWithHiddenLanguage, 'en');
      expect(enBook.getChapterSummaries('en').isNotEmpty, isTrue);

      // Arabic is hidden in hiddenLanguages
      expect(
        () => ProtectedTextService.hydrate(bookWithHiddenLanguage, 'ar'),
        throwsA(isA<UnpublishedLanguageException>()),
      );
    });

    test('7. Unpublished book is rejected with ContentUnavailableException', () async {
      mockAuth.setLoggedInUser(primaryPremiumUser);

      final unpublishedBook = Book.fromMap('draft_book', {
        'title': {'en': 'Draft'},
        'author': {'en': 'Draft Author'},
        'isPremium': true,
        'isPublished': false, // Unpublished
        'chapterSummaries': {'en': [{'title': 'Ch 1', 'content': 'Draft'}]},
      });

      expect(
        () => ProtectedTextService.hydrate(unpublishedBook, 'en'),
        throwsA(isA<ContentUnavailableException>()),
      );
    });

    test('8. Offline condition distinction: NetworkGuard connection check prevents false offline labeling', () async {
      mockAuth.setLoggedInUser(primaryPremiumUser);

      // Online with content available -> succeeds immediately
      NetworkGuard.mockConnectionStatus = true;
      final book = await ProtectedTextService.hydrate(premiumBookAtomicHabits, 'en');
      expect(book, isNotNull);

      // Simulate genuine offline condition on a book whose content is stripped/unmigrated
      NetworkGuard.mockConnectionStatus = false;
      final unhydratedPremiumBook = Book.fromMap('unmigrated_book', {
        'title': {'en': 'Unmigrated Book'},
        'isPremium': true,
        'isPublished': true,
        'chapterSummaries': {
          'en': [{'title': 'Ch 1', 'content': ''}], // Empty content needing remote hydration
        },
      });

      expect(
        () => ProtectedTextService.hydrate(unhydratedPremiumBook, 'en'),
        throwsA(isA<ContentUnavailableException>()),
      );
    });
  });
}
