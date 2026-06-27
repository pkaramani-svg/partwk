import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/book.dart';
import 'service_locator.dart';

abstract class AuthService extends ChangeNotifier {
  final _completionCelebrationController = StreamController<Book>.broadcast();
  Stream<Book> get completionCelebrationStream => _completionCelebrationController.stream;

  void triggerCompletionCelebration(Book book) {
    _completionCelebrationController.add(book);
  }

  final _doubleLoginController = StreamController<void>.broadcast();
  Stream<void> get doubleLoginStream => _doubleLoginController.stream;

  void triggerDoubleLogin() {
    _doubleLoginController.add(null);
  }

  final _accountSuspendedController = StreamController<void>.broadcast();
  Stream<void> get accountSuspendedStream => _accountSuspendedController.stream;

  void triggerAccountSuspended() {
    _accountSuspendedController.add(null);
  }

  UserModel? get currentUser;
  bool get isAuthenticated;
  bool get isGuest;
  Future<void> initialize();
  Future<void> signInWithEmailAndPassword(String email, String password);
  Future<void> registerWithEmailAndPassword(String name, String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();
  Future<void> checkAndUnlockAchievements();
  Future<void> signInAsGuest();
  Future<void> signOut();
  Future<void> updateSelectedLanguage(String langCode);
  Future<void> updateInterests(List<String> interests);
  Future<void> updateGoals(List<String> goals);
  Future<void> addSavedBook(String bookId);
  Future<void> removeSavedBook(String bookId);
  Future<void> addLikedBook(String bookId);
  Future<void> removeLikedBook(String bookId);
  Future<void> addCompletedBook(String bookId, {String source = 'automatic', DateTime? completedAt});
  Future<void> removeCompletedBook(String bookId);
  Future<void> linkFamilyMember(String email);
  Future<void> upgradeToPremium();
  Future<void> updateListeningProgress(String bookId, String langCode, int chapterIndex, int positionSeconds, {int accumulatedSecondHalfSeconds = 0, bool localOnly = false});
  Future<void> recordActivity();
  Future<void> addLearningTime(int seconds);
  Future<void> updatePresence({required String screen, String? bookTitle, String? bookId, String? activityType});
  Future<void> setOnlineStatus(bool isOnline);
}

class MockAuthService extends AuthService {
  UserModel? _currentUser;
  bool _isGuest = false;

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  bool get isGuest => _isGuest;

  MockAuthService() {
    // Start with null (needs onboarding/login)
  }

  @override
  Future<void> initialize() async {
    // Mock instantly initialized
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _isGuest = false;
    _currentUser = UserModel(
      id: 'mock-user-123',
      name: email.split('@')[0].toUpperCase(),
      email: email,
      selectedLanguage: 'en',
      interests: [],
      learningGoals: [],
      savedBooks: [],
      completedBooks: [],
      likedBooks: [],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'free',
      streakCount: 1,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> registerWithEmailAndPassword(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    _isGuest = false;
    _currentUser = UserModel(
      id: 'mock-user-123',
      name: name,
      email: email,
      selectedLanguage: 'en',
      interests: [],
      learningGoals: [],
      savedBooks: [],
      completedBooks: [],
      likedBooks: [],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'free',
      streakCount: 1,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> resetPassword(String email) async {
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Future<void> signInWithGoogle() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _isGuest = false;
    _currentUser = UserModel(
      id: 'google-user-123',
      name: 'Google User',
      email: 'google.user@gmail.com',
      selectedLanguage: 'en',
      interests: [],
      learningGoals: [],
      savedBooks: [],
      completedBooks: [],
      likedBooks: [],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'free',
      streakCount: 3,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signInWithApple() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _isGuest = false;
    _currentUser = UserModel(
      id: 'apple-user-123',
      name: 'Apple User',
      email: 'apple.user@icloud.com',
      selectedLanguage: 'en',
      interests: [],
      learningGoals: [],
      savedBooks: [],
      completedBooks: [],
      likedBooks: [],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'premium', // Pre-simulate premium for easy testing
      streakCount: 5,
      lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signInAsGuest() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _isGuest = true;
    _currentUser = UserModel(
      id: 'guest-user-123',
      name: 'Guest Reader',
      email: 'guest@partwk.com',
      selectedLanguage: 'en',
      interests: [],
      learningGoals: [],
      savedBooks: [],
      completedBooks: [],
      likedBooks: [],
      listeningProgress: {},
      readingProgress: {},
      subscriptionStatus: 'free',
      streakCount: 0,
      lastActiveDate: '',
      familyMembers: [],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _isGuest = false;
    notifyListeners();
  }

  @override
  Future<void> updateSelectedLanguage(String langCode) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(selectedLanguage: langCode);
      notifyListeners();
    }
  }

  @override
  Future<void> updateInterests(List<String> interests) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(interests: interests);
      notifyListeners();
    }
  }

  @override
  Future<void> updateGoals(List<String> goals) async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(learningGoals: goals);
      notifyListeners();
    }
  }

  @override
  Future<void> addSavedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedSaved = List<String>.from(_currentUser!.savedBooks);
      if (!updatedSaved.contains(bookId)) {
        updatedSaved.add(bookId);
        _currentUser = _currentUser!.copyWith(savedBooks: updatedSaved);
        notifyListeners();
      }
    }
  }

  @override
  Future<void> removeSavedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedSaved = List<String>.from(_currentUser!.savedBooks)..remove(bookId);
      _currentUser = _currentUser!.copyWith(savedBooks: updatedSaved);
      notifyListeners();
    }
  }

  @override
  Future<void> addLikedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedLiked = List<String>.from(_currentUser!.likedBooks);
      if (!updatedLiked.contains(bookId)) {
        updatedLiked.add(bookId);
        _currentUser = _currentUser!.copyWith(likedBooks: updatedLiked);
        notifyListeners();
      }
    }
  }

  @override
  Future<void> removeLikedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedLiked = List<String>.from(_currentUser!.likedBooks)..remove(bookId);
      _currentUser = _currentUser!.copyWith(likedBooks: updatedLiked);
      notifyListeners();
    }
  }

  @override
  Future<void> addCompletedBook(String bookId, {String source = 'automatic', DateTime? completedAt}) async {
    if (_currentUser != null) {
      final alreadyCompleted = _currentUser!.completedBooks.contains(bookId);
      final updatedCompleted = List<String>.from(_currentUser!.completedBooks);
      if (!updatedCompleted.contains(bookId)) {
        updatedCompleted.add(bookId);
      }
      final updatedDetails = Map<String, dynamic>.from(_currentUser!.completionDetails);
      updatedDetails[bookId] = {
        'completed': true,
        'source': source,
        'completedAt': (completedAt ?? DateTime.now()).toIso8601String(),
      };
      
      _currentUser = _currentUser!.copyWith(
        completedBooks: updatedCompleted,
        completionDetails: updatedDetails,
      );
      notifyListeners();

      if (!alreadyCompleted) {
        try {
          final books = await AppLocator.db.fetchBooks();
          final book = books.firstWhere((b) => b.id == bookId);
          triggerCompletionCelebration(book);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> removeCompletedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedCompleted = List<String>.from(_currentUser!.completedBooks)..remove(bookId);
      final updatedDetails = Map<String, dynamic>.from(_currentUser!.completionDetails);
      updatedDetails[bookId] = {
        'completed': false,
        'completedAt': DateTime.now().toIso8601String(),
      };
      _currentUser = _currentUser!.copyWith(
        completedBooks: updatedCompleted,
        completionDetails: updatedDetails,
      );
      notifyListeners();
    }
  }

  @override
  Future<void> linkFamilyMember(String email) async {
    if (_currentUser != null) {
      final normalizedEmail = email.trim().toLowerCase();
      final updatedFamily = List<String>.from(_currentUser!.familyMembers);
      if (!updatedFamily.contains(normalizedEmail)) {
        updatedFamily.add(normalizedEmail);
        _currentUser = _currentUser!.copyWith(familyMembers: updatedFamily);
        notifyListeners();
      }
    }
  }

  @override
  Future<void> checkAndUnlockAchievements() async {
    // Mock implementation does nothing
  }

  @override
  Future<void> upgradeToPremium() async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(subscriptionStatus: 'premium');
      notifyListeners();
    }
  }

  @override
  Future<void> updateListeningProgress(String bookId, String langCode, int chapterIndex, int positionSeconds, {int accumulatedSecondHalfSeconds = 0, bool localOnly = false}) async {}

  @override
  Future<void> addLearningTime(int seconds) async {}

  @override
  Future<void> recordActivity() async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        streakCount: _currentUser!.streakCount + 1,
        lastActiveDate: DateTime.now().toIso8601String().substring(0, 10),
      );
      notifyListeners();
    }
  }

  @override
  Future<void> updatePresence({required String screen, String? bookTitle, String? bookId, String? activityType}) async {}

  @override
  Future<void> setOnlineStatus(bool isOnline) async {}
}
