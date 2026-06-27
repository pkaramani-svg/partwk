import 'dart:convert';
import 'dart:math' as dart_math;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../models/user.dart';
import '../../services/notification_service.dart';
import 'auth_service.dart';
import 'package:dio/dio.dart';
import '../../core/services/service_locator.dart';
import 'network_guard.dart';
import 'offline_availability_repository.dart';
import 'analytics_service.dart';

class FirebaseAuthService extends AuthService {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _isGuest = false;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;
  bool _isSigningIn = false;

  FirebaseAuthService() {
    _firebaseAuth.authStateChanges().listen((user) async {
      if (user != null) {
        if (!user.isAnonymous) {
          _isGuest = false;
          if (_isSigningIn) {
            return;
          }
          await _fetchUserData(user.uid);
          await _setupUserDocListener(user.uid);
          _startPresenceTimer();
          setOnlineStatus(true);
          try {
            await AppLocator.audio.init();
          } catch (e) {
            print('Error re-initializing audio on auth change: $e');
          }
        }
      } else {
        await _userDocSubscription?.cancel();
        _userDocSubscription = null;
        if (_currentUser != null) {
          await setOnlineStatus(false);
        }
        _stopPresenceTimer();
        _currentUser = null;
        _isGuest = false;
        try {
          await AppLocator.audio.init();
        } catch (e) {
          print('Error re-initializing audio on signout: $e');
        }
        notifyListeners();
      }
    });
  }

  Future<void> _setupUserDocListener(String uid) async {
    await _userDocSubscription?.cancel();
    
    final prefs = await SharedPreferences.getInstance();
    String? localSessionId = prefs.getString('current_session_id');
    
    if (localSessionId == null) {
      localSessionId = const Uuid().v4();
      await prefs.setString('current_session_id', localSessionId);
      try {
        await _firestore.collection('users').doc(uid).set({
          'currentSessionId': localSessionId,
        }, SetOptions(merge: true));
      } catch (e) {
        print("Error saving session ID to firestore: $e");
      }
    }

    _userDocSubscription = _firestore.collection('users').doc(uid).snapshots().listen((doc) async {
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final status = data['status'] as String?;
          if (status == 'suspended') {
            print("User is suspended! Logging out...");
            await _userDocSubscription?.cancel();
            _userDocSubscription = null;
            
            await signOut();
            triggerAccountSuspended();
            return;
          }
          
          final firestoreSessionId = data['currentSessionId'] as String?;
          if (firestoreSessionId != null && firestoreSessionId != localSessionId) {
            print("Double login detected! Expected $localSessionId but found $firestoreSessionId. Logging out...");
            await _userDocSubscription?.cancel();
            _userDocSubscription = null;
            
            await signOut();
            triggerDoubleLogin();
          }
        }
      }
    });
  }

  @override
  UserModel? get currentUser => _currentUser;

  @override
  bool get isAuthenticated => _currentUser != null;

  @override
  bool get isGuest => _isGuest;

  @override
  Future<void> initialize() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.isAnonymous) {
      _isGuest = false;
      // Load cached user immediately for offline startup support
      final cached = await OfflineAvailabilityRepository.getCachedUser();
      if (cached != null && cached.id == user.uid) {
        _currentUser = cached;
        notifyListeners();
        // Trigger fetch in background to avoid blocking splash screen on offline startup
        _fetchUserData(user.uid).catchError((e) {
          debugPrint('Background user fetch error: $e');
        });
      } else {
        try {
          await _fetchUserData(user.uid).timeout(const Duration(seconds: 2));
        } catch (e) {
          debugPrint('Startup user fetch timed out or failed: $e');
        }
      }
    } else if (user != null && user.isAnonymous) {
      _isGuest = true;
      // create guest user object immediately
      _currentUser = UserModel(
        id: user.uid,
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
    } else {
      _currentUser = null;
      _isGuest = false;
    }
    try {
      await AppLocator.audio.init();
    } catch (e) {
      print('Error re-initializing audio in auth initialize: $e');
    }
    notifyListeners();
  }

  Future<void> _fetchUserData(String uid, {bool throwOnError = false}) async {
    try {
      final hasInternet = await NetworkGuard.hasConnection();
      final doc = await _firestore.collection('users').doc(uid).get(
        GetOptions(source: hasInternet ? Source.serverAndCache : Source.cache),
      );
      if (doc.exists) {
        final data = doc.data()!;
        if (data['status'] == 'suspended') {
          await _firebaseAuth.signOut();
          _currentUser = null;
          _isGuest = false;
          await OfflineAvailabilityRepository.clearCachedUser();
          notifyListeners();
          
          final prefs = await SharedPreferences.getInstance();
          final langCode = prefs.getString('language_code') ?? 'en';
          final errorMsg = langCode == 'ku'
              ? 'هەژمارەکەت ڕاگیراوە. تکایە پەیوەندی بکە بە پشتگیری لە support@partwk.com.'
              : (langCode == 'ar'
                  ? 'تم تعليق حسابك. يرجى الاتصال بالدعم على support@partwk.com.'
                  : 'Your account has been suspended. Please contact support at support@partwk.com.');
          throw errorMsg;
        }

        final serverUser = UserModel.fromMap(doc.id, data);
        UserModel mergedUser = serverUser;

        // Try merging local cached updates if user matches (offline manual completion & progress)
        try {
          final localUser = await OfflineAvailabilityRepository.getCachedUser();
          if (localUser != null && localUser.id == uid) {
            final mergedDetails = Map<String, dynamic>.from(serverUser.completionDetails);
            final mergedListening = Map<String, dynamic>.from(serverUser.listeningProgress);
            final mergedReading = Map<String, double>.from(serverUser.readingProgress);
            bool hasChanges = false;
            
            localUser.completionDetails.forEach((bookId, localVal) {
              if (localVal is Map) {
                final serverVal = serverUser.completionDetails[bookId];
                if (serverVal == null) {
                  mergedDetails[bookId] = localVal;
                  hasChanges = true;
                } else if (serverVal is Map) {
                  final localTimeStr = localVal['completedAt'] as String?;
                  final serverTimeStr = serverVal['completedAt'] as String?;
                  if (localTimeStr != null && serverTimeStr != null) {
                    final localTime = DateTime.tryParse(localTimeStr);
                    final serverTime = DateTime.tryParse(serverTimeStr);
                    if (localTime != null && serverTime != null && localTime.isAfter(serverTime)) {
                      mergedDetails[bookId] = localVal;
                      hasChanges = true;
                    }
                  }
                }
              }
            });

            localUser.listeningProgress.forEach((progressKey, localVal) {
              if (localVal is Map) {
                final serverVal = serverUser.listeningProgress[progressKey];
                if (serverVal == null) {
                  mergedListening[progressKey] = localVal;
                  hasChanges = true;
                } else if (serverVal is Map) {
                  final localChapter = localVal['chapterIndex'] as int? ?? 0;
                  final serverChapter = serverVal['chapterIndex'] as int? ?? 0;
                  final localPos = localVal['positionSeconds'] as int? ?? 0;
                  final serverPos = serverVal['positionSeconds'] as int? ?? 0;
                  
                  if (localChapter > serverChapter || 
                      (localChapter == serverChapter && localPos > serverPos)) {
                    mergedListening[progressKey] = localVal;
                    hasChanges = true;
                  }
                }
              }
            });

            localUser.readingProgress.forEach((bookId, localVal) {
              final serverVal = serverUser.readingProgress[bookId];
              if (serverVal == null || localVal > serverVal) {
                mergedReading[bookId] = localVal;
                hasChanges = true;
              }
            });

            if (hasChanges) {
              final List<String> completedList = List<String>.from(serverUser.completedBooks);
              mergedDetails.forEach((bookId, detail) {
                if (detail is Map && detail['completed'] == true) {
                  if (!completedList.contains(bookId)) {
                    completedList.add(bookId);
                  }
                } else {
                  completedList.remove(bookId);
                }
              });
              
              mergedUser = serverUser.copyWith(
                completionDetails: mergedDetails,
                completedBooks: completedList,
                listeningProgress: mergedListening,
                readingProgress: mergedReading,
              );
              
              // Sync merged user back to Firestore
              await _firestore.collection('users').doc(uid).set(mergedUser.toMap(), SetOptions(merge: true));
            }
          }
        } catch (e) {
          print("Error merging offline data: $e");
        }

        _currentUser = mergedUser;
        _isGuest = false;
        
        // 1. Check Family Premium Status
        try {
          bool updatedHasFamilyPremium = false;
          if (_currentUser!.email.isNotEmpty) {
            final familyQuery = await _firestore.collection('users')
                .where('familyMembers', arrayContains: _currentUser!.email.toLowerCase())
                .limit(1)
                .get();
            if (familyQuery.docs.isNotEmpty) {
              final ownerData = familyQuery.docs.first.data();
              final ownerSub = ownerData['subscriptionStatus'] as String?;
              final ownerRole = ownerData['role'] as String?;
              
              if (ownerSub == 'premium' || ownerSub == 'pro' || ownerRole == 'admin') {
                updatedHasFamilyPremium = true;
              }
            }
          }
          if (_currentUser!.hasFamilyPremium != updatedHasFamilyPremium) {
            _currentUser = _currentUser!.copyWith(hasFamilyPremium: updatedHasFamilyPremium);
            await _firestore.collection('users').doc(uid).update({
              'hasFamilyPremium': updatedHasFamilyPremium,
            });
          }
        } catch (e) {
          print("Error checking family premium: $e");
        }

        // Cache the fully populated user model locally
        await OfflineAvailabilityRepository.cacheUser(_currentUser!);

        // 2. Check Achievements
        await checkAndUnlockAchievements();
        
        final fcmToken = await NotificationService().getToken();
        if (fcmToken != null && fcmToken.isNotEmpty) {
          await _firestore.collection('users').doc(uid).set({'fcmToken': fcmToken}, SetOptions(merge: true));
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (throwOnError) {
        rethrow;
      }
      // If fetching fails, fallback to local cached user profile
      final cached = await OfflineAvailabilityRepository.getCachedUser();
      if (cached != null && cached.id == uid) {
        _currentUser = cached;
        _isGuest = false;
        notifyListeners();
      }
    }
  }

  Future<void> _createUserDocument(auth.User user, String name) async {
    final newUser = UserModel(
      id: user.uid,
      name: name,
      email: user.email?.toLowerCase() ?? '',
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
    final userMap = newUser.toMap();
    final fcmToken = await NotificationService().getToken();
    if (fcmToken != null) {
      userMap['fcmToken'] = fcmToken;
    }
    
    final prefs = await SharedPreferences.getInstance();
    String? localSessionId = prefs.getString('current_session_id');
    if (localSessionId == null) {
      localSessionId = const Uuid().v4();
      await prefs.setString('current_session_id', localSessionId);
    }
    userMap['currentSessionId'] = localSessionId;

    await _firestore.collection('users').doc(user.uid).set(userMap);
    _currentUser = newUser;
    _isGuest = false;
    notifyListeners();
  }

  Future<void> _updateUserDocument(UserModel updatedUser) async {
    if (_currentUser == null || _isGuest) return;
    _currentUser = updatedUser;
    notifyListeners();
    
    // Save to local cache immediately to ensure offline resilience
    await OfflineAvailabilityRepository.cacheUser(updatedUser);
    
    try {
      await _firestore.collection('users').doc(updatedUser.id).set(updatedUser.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint("Offline mode: User profile update queued in Firestore: $e");
    }
  }

  @override
  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _isSigningIn = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final newSessionId = const Uuid().v4();
      await prefs.setString('current_session_id', newSessionId);

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email.trim().toLowerCase(), password: password);
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'currentSessionId': newSessionId,
        }, SetOptions(merge: true));
        await _fetchUserData(credential.user!.uid, throwOnError: true);
        await _setupUserDocListener(credential.user!.uid);
      }
    } finally {
      _isSigningIn = false;
    }
  }

  @override
  Future<void> registerWithEmailAndPassword(String name, String email, String password) async {
    _isSigningIn = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final newSessionId = const Uuid().v4();
      await prefs.setString('current_session_id', newSessionId);

      final result = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email.trim().toLowerCase(), password: password);
      if (result.user != null) {
        await _createUserDocument(result.user!, name);
        await _fetchUserData(result.user!.uid, throwOnError: true);
        await _setupUserDocListener(result.user!.uid);
      }
    } finally {
      _isSigningIn = false;
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw 'Email is not registered in our system.';
      }

      final dio = Dio();
      final response = await dio.post(
        'https://us-central1-partwk-bd4ec.cloudfunctions.net/sendCustomPasswordReset',
        data: {
          'data': {
            'email': email,
          }
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode != 200) {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      if (e is DioException) {
        throw 'Failed to send custom password reset email: ${e.message}';
      }
      if (e is FirebaseException) {
        throw 'Failed to check database: ${e.message}';
      }
      throw e.toString();
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    _isSigningIn = true;
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // User canceled

      final prefs = await SharedPreferences.getInstance();
      final newSessionId = const Uuid().v4();
      await prefs.setString('current_session_id', newSessionId);

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final auth.OAuthCredential credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth.UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      if (userCredential.user != null) {
        final doc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        if (!doc.exists) {
          await _createUserDocument(userCredential.user!, googleUser.displayName ?? 'Google User');
          await _setupUserDocListener(userCredential.user!.uid);
        } else {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'currentSessionId': newSessionId,
          }, SetOptions(merge: true));
          await _fetchUserData(userCredential.user!.uid, throwOnError: true);
          await _setupUserDocListener(userCredential.user!.uid);
        }
      }
    } catch (e) {
      print('Google sign in error: $e');
      throw e;
    } finally {
      _isSigningIn = false;
    }
  }

  /// Generates a cryptographic nonce for Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = dart_math.Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<void> signInWithApple() async {
    _isSigningIn = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final newSessionId = const Uuid().v4();
      await prefs.setString('current_session_id', newSessionId);

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final auth.OAuthCredential credential = auth.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final auth.UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      if (userCredential.user != null) {
        final doc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        if (!doc.exists) {
          final String name = (appleCredential.givenName != null && appleCredential.familyName != null)
              ? '${appleCredential.givenName} ${appleCredential.familyName}'
              : 'Apple User';
          await _createUserDocument(userCredential.user!, name);
          await _setupUserDocListener(userCredential.user!.uid);
        } else {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'currentSessionId': newSessionId,
          }, SetOptions(merge: true));
          await _fetchUserData(userCredential.user!.uid, throwOnError: true);
          await _setupUserDocListener(userCredential.user!.uid);
        }
      }
    } catch (e) {
      print('Apple sign in error: $e');
      throw e;
    } finally {
      _isSigningIn = false;
    }
  }

  @override
  Future<void> signInAsGuest() async {
    try {
      await _firebaseAuth.signInAnonymously();
      _isGuest = true;
    } catch (e) {
      print('Firebase Anonymous Auth failed: $e. Falling back to local offline guest mode.');
      _isGuest = true;
    }
    _currentUser = UserModel(
      id: _firebaseAuth.currentUser?.uid ?? 'guest-id',
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
    await _userDocSubscription?.cancel();
    _userDocSubscription = null;
    if (_currentUser != null) {
      await setOnlineStatus(false);
    }
    _stopPresenceTimer();
    await _firebaseAuth.signOut();
    _currentUser = null;
    _isGuest = false;
    await OfflineAvailabilityRepository.clearCachedUser();
    notifyListeners();
  }

  @override
  Future<void> updateSelectedLanguage(String langCode) async {
    if (_currentUser != null) {
      await _updateUserDocument(_currentUser!.copyWith(selectedLanguage: langCode));
    }
  }

  @override
  Future<void> updateInterests(List<String> interests) async {
    if (_currentUser != null) {
      await _updateUserDocument(_currentUser!.copyWith(interests: interests));
    }
  }

  @override
  Future<void> updateGoals(List<String> goals) async {
    if (_currentUser != null) {
      await _updateUserDocument(_currentUser!.copyWith(learningGoals: goals));
    }
  }

  @override
  Future<void> addSavedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedSaved = List<String>.from(_currentUser!.savedBooks);
      if (!updatedSaved.contains(bookId)) {
        updatedSaved.add(bookId);
        await _updateUserDocument(_currentUser!.copyWith(savedBooks: updatedSaved));
      }
    }
  }

  @override
  Future<void> removeSavedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedSaved = List<String>.from(_currentUser!.savedBooks)..remove(bookId);
      await _updateUserDocument(_currentUser!.copyWith(savedBooks: updatedSaved));
    }
  }

  @override
  Future<void> addLikedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedLiked = List<String>.from(_currentUser!.likedBooks);
      if (!updatedLiked.contains(bookId)) {
        updatedLiked.add(bookId);
        await _updateUserDocument(_currentUser!.copyWith(likedBooks: updatedLiked));
      }
    }
  }

  @override
  Future<void> removeLikedBook(String bookId) async {
    if (_currentUser != null) {
      final updatedLiked = List<String>.from(_currentUser!.likedBooks)..remove(bookId);
      await _updateUserDocument(_currentUser!.copyWith(likedBooks: updatedLiked));
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
      
      final updatedUser = _currentUser!.copyWith(
        completedBooks: updatedCompleted,
        completionDetails: updatedDetails,
      );
      
      await _updateUserDocument(updatedUser);
      await checkAndUnlockAchievements();

      // Track analytics completion events
      AnalyticsService.trackEvent(
        source == 'manual' ? 'book_completed_manual' : 'book_completed_automatic',
        parameters: {'bookId': bookId},
      );

      // Trigger the celebration popup if it's a new completion
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
      
      final updatedUser = _currentUser!.copyWith(
        completedBooks: updatedCompleted,
        completionDetails: updatedDetails,
      );
      
      await _updateUserDocument(updatedUser);
    }
  }

  @override
  Future<void> linkFamilyMember(String email) async {
    if (_currentUser != null) {
      final normalizedEmail = email.trim().toLowerCase();
      final updatedFamily = List<String>.from(_currentUser!.familyMembers);
      if (!updatedFamily.contains(normalizedEmail)) {
        updatedFamily.add(normalizedEmail);
        await _updateUserDocument(_currentUser!.copyWith(familyMembers: updatedFamily));
        
        try {
          final querySnap = await _firestore.collection('users')
              .where('email', isEqualTo: normalizedEmail)
              .get();
          for (final doc in querySnap.docs) {
            await doc.reference.update({
              'hasFamilyPremium': true,
            });
          }
        } catch (e) {
          print("Error updating linked family member hasFamilyPremium status: $e");
        }
      }
    }
  }

  @override
  Future<void> upgradeToPremium() async {
    if (_currentUser != null) {
      await _updateUserDocument(_currentUser!.copyWith(subscriptionStatus: 'premium'));
    }
  }

  @override
  Future<void> updateListeningProgress(String bookId, String langCode, int chapterIndex, int positionSeconds, {int accumulatedSecondHalfSeconds = 0, bool localOnly = false}) async {
    if (_currentUser == null) return;
    try {
      final updatedProgress = Map<String, dynamic>.from(_currentUser!.listeningProgress);
      updatedProgress['${bookId}_$langCode'] = {
        'chapterIndex': chapterIndex,
        'positionSeconds': positionSeconds,
        'accumulatedSecondHalfSeconds': accumulatedSecondHalfSeconds,
      };
      final updatedUser = _currentUser!.copyWith(listeningProgress: updatedProgress);
      
      if (localOnly) {
        _currentUser = updatedUser;
        notifyListeners();
        await OfflineAvailabilityRepository.cacheUser(updatedUser);
      } else {
        await _updateUserDocument(updatedUser);
        await checkAndUnlockAchievements();
      }
    } catch (e) {
      debugPrint("Error updating listening progress: $e");
    }
  }

  int _dailyLearningSeconds = 0;

  @override
  Future<void> addLearningTime(int seconds) async {
    _dailyLearningSeconds += seconds;
    // Require 60 seconds of genuine learning before counting towards streak
    if (_dailyLearningSeconds >= 60) {
      await recordActivity();
      _dailyLearningSeconds = 0; // reset after triggering
    }
  }

  @override
  Future<void> recordActivity() async {
    if (_currentUser == null) return;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastActive = _currentUser!.lastActiveDate;

    if (lastActive == today) {
      // Already recorded activity today, do nothing.
      return;
    }

    final yesterday = DateTime.now().subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);
    
    int newStreak = _currentUser!.streakCount;
    if (lastActive == yesterday) {
      // Active yesterday, maintain and increment streak
      newStreak += 1;
    } else {
      // Missed a day (or first time), reset to 1
      newStreak = 1;
    }

    await _updateUserDocument(_currentUser!.copyWith(
      streakCount: newStreak,
      lastActiveDate: today,
    ));
    
    await checkAndUnlockAchievements();
  }

  @override
  Future<void> checkAndUnlockAchievements() async {
    if (_currentUser == null) return;
    
    final currentUnlocked = List<String>.from(_currentUser!.unlockedAchievements);
    bool newlyUnlocked = false;

    void check(String id, bool condition) {
      if (condition && !currentUnlocked.contains(id)) {
        currentUnlocked.add(id);
        newlyUnlocked = true;
      }
    }

    final allBooks = await AppLocator.db.fetchBooks();
    final int streakCount = _currentUser!.streakCount;

    // Bilingual Explorer
    final langsList = <String>{};
    for (final key in _currentUser!.listeningProgress.keys) {
      final parts = key.split('_');
      if (parts.length >= 2) langsList.add(parts.last);
    }

    for (final lang in ['en', 'ku', 'ar']) {
      final langCompletedCount = _currentUser!.completedBooks.where((id) {
        return allBooks.any((book) => book.id == id && book.hasContentForLanguage(lang));
      }).length;
      
      final langSavedCount = _currentUser!.savedBooks.where((id) {
        return allBooks.any((book) => book.id == id && book.hasContentForLanguage(lang));
      }).length;
      
      final langLikedCount = _currentUser!.likedBooks.where((id) {
        return allBooks.any((book) => book.id == id && book.hasContentForLanguage(lang));
      }).length;

      // Books Completed
      check('ach-books-1-$lang', langCompletedCount >= 1);
      check('ach-books-5-$lang', langCompletedCount >= 5);
      check('ach-books-10-$lang', langCompletedCount >= 10);
      check('ach-books-25-$lang', langCompletedCount >= 25);
      check('ach-books-50-$lang', langCompletedCount >= 50);
      check('ach-books-100-$lang', langCompletedCount >= 100);

      // Streaks
      check('ach-streak-3-$lang', streakCount >= 3);
      check('ach-streak-7-$lang', streakCount >= 7);
      check('ach-streak-14-$lang', streakCount >= 14);
      check('ach-streak-30-$lang', streakCount >= 30);
      check('ach-streak-100-$lang', streakCount >= 100);

      // Saved Books
      check('ach-saved-1-$lang', langSavedCount >= 1);
      check('ach-saved-10-$lang', langSavedCount >= 10);
      check('ach-saved-50-$lang', langSavedCount >= 50);

      // Liked Books
      check('ach-liked-1-$lang', langLikedCount >= 1);
      check('ach-liked-10-$lang', langLikedCount >= 10);
      check('ach-liked-50-$lang', langLikedCount >= 50);

      check('ach-polyglot-2-$lang', langsList.length >= 2);
      check('ach-polyglot-3-$lang', langsList.length >= 3);

      // Time (Proxy: 15 mins per completed book)
      final totalHours = (langCompletedCount * 15) / 60;
      check('ach-time-1-$lang', totalHours >= 1);
      check('ach-time-10-$lang', totalHours >= 10);
      check('ach-time-50-$lang', totalHours >= 50);
    }

    if (newlyUnlocked) {
      await _updateUserDocument(_currentUser!.copyWith(unlockedAchievements: currentUnlocked));
    }
  }

  Timer? _presenceTimer;
  Map<String, dynamic>? _lastActivityState;

  void _startPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_currentUser != null && !_isGuest) {
        setOnlineStatus(true);
      }
    });
  }

  void _stopPresenceTimer() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  @override
  Future<void> updatePresence({required String screen, String? bookTitle, String? bookId, String? activityType}) async {
    if (_currentUser == null || _isGuest) return;
    
    final nowIso = DateTime.now().toIso8601String();
    final activity = {
      'screen': screen,
      'bookTitle': bookTitle,
      'bookId': bookId,
      'type': activityType ?? 'browsing',
      'updatedAt': nowIso,
    };
    _lastActivityState = activity;

    _currentUser = _currentUser!.copyWith(
      lastSeen: nowIso,
      currentActivity: activity,
    );
    notifyListeners();

    try {
      await _firestore.collection('users').doc(_currentUser!.id).set({
        'lastSeen': nowIso,
        'isOnline': true,
        'currentActivity': activity,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Offline mode: Presence update queued/ignored: $e");
    }
  }

  @override
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_currentUser == null || _isGuest) return;
    
    final nowIso = DateTime.now().toIso8601String();
    _currentUser = _currentUser!.copyWith(
      lastSeen: nowIso,
    );
    notifyListeners();

    try {
      final data = <String, dynamic>{
        'lastSeen': nowIso,
        'isOnline': isOnline,
      };
      if (_lastActivityState != null) {
        data['currentActivity'] = _lastActivityState;
      }
      await _firestore.collection('users').doc(_currentUser!.id).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Offline mode: Online status update queued/ignored: $e");
    }
  }
}
