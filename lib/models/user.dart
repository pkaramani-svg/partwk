import 'book.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String selectedLanguage;
  final List<String> interests;
  final List<String> learningGoals;
  final List<String> savedBooks;
  final List<String> completedBooks;
  final List<String> likedBooks;
  
  // bookId -> listening progress object {chapterIndex: x, positionSeconds: y}
  final Map<String, dynamic> listeningProgress;
  // bookId -> reading progress percentage (0.0 to 1.0)
  final Map<String, double> readingProgress;
  
  // bookId -> { 'completed': bool, 'source': 'automatic'|'manual', 'completedAt': String (ISO) }
  final Map<String, dynamic> completionDetails;

  final String subscriptionStatus; // 'free' or 'premium'
  final int streakCount;
  final String lastActiveDate; // YYYY-MM-DD
  final List<String> familyMembers; // List of family member emails
  final DateTime createdAt;
  
  final String? subscriptionStartDate;
  final String? subscriptionExpiryDate;
  
  final bool hasFamilyPremium;
  final List<String> unlockedAchievements;

  final String? lastSeen;
  final Map<String, dynamic>? currentActivity;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.selectedLanguage,
    required this.interests,
    required this.learningGoals,
    required this.savedBooks,
    required this.completedBooks,
    required this.likedBooks,
    required this.listeningProgress,
    required this.readingProgress,
    required this.subscriptionStatus,
    required this.streakCount,
    required this.lastActiveDate,
    required this.familyMembers,
    required this.createdAt,
    this.subscriptionStartDate,
    this.subscriptionExpiryDate,
    this.hasFamilyPremium = false,
    this.unlockedAchievements = const [],
    this.completionDetails = const {},
    this.lastSeen,
    this.currentActivity,
  });

  bool get isPremium {
    if (subscriptionStatus != 'premium' && subscriptionStatus != 'pro' && !hasFamilyPremium) {
      return false;
    }
    if (subscriptionExpiryDate != null && subscriptionExpiryDate!.isNotEmpty) {
      try {
        final expiry = DateTime.parse(subscriptionExpiryDate!);
        if (DateTime.now().isAfter(expiry)) {
          return false;
        }
      } catch (_) {}
    }
    return true;
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      name: data['name'] ?? 'User',
      email: data['email'] ?? '',
      selectedLanguage: data['selectedLanguage'] ?? 'en',
      interests: List<String>.from(data['interests'] ?? []),
      learningGoals: List<String>.from(data['learningGoals'] ?? []),
      savedBooks: List<String>.from(data['savedBooks'] ?? []),
      completedBooks: List<String>.from(data['completedBooks'] ?? []),
      likedBooks: List<String>.from(data['likedBooks'] ?? []),
      listeningProgress: Map<String, dynamic>.from(data['listeningProgress'] ?? {}),
      readingProgress: (data['readingProgress'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          ) ??
          {},
      subscriptionStatus: data['subscriptionStatus'] ?? 'free',
      streakCount: data['streakCount'] ?? 0,
      lastActiveDate: data['lastActiveDate'] ?? '',
      familyMembers: List<String>.from(data['familyMembers'] ?? []),
      createdAt: data['createdAt'] != null ? DateTime.parse(data['createdAt']) : DateTime.now(),
      subscriptionStartDate: data['subscriptionStartDate'],
      subscriptionExpiryDate: data['subscriptionExpiryDate'],
      hasFamilyPremium: data['hasFamilyPremium'] ?? false,
      unlockedAchievements: List<String>.from(data['unlockedAchievements'] ?? []),
      completionDetails: Map<String, dynamic>.from(data['completionDetails'] ?? {}),
      lastSeen: data['lastSeen'],
      currentActivity: data['currentActivity'] != null ? Map<String, dynamic>.from(data['currentActivity']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'selectedLanguage': selectedLanguage,
      'interests': interests,
      'learningGoals': learningGoals,
      'savedBooks': savedBooks,
      'completedBooks': completedBooks,
      'likedBooks': likedBooks,
      'listeningProgress': listeningProgress,
      'readingProgress': readingProgress,
      'subscriptionStatus': subscriptionStatus,
      'streakCount': streakCount,
      'lastActiveDate': lastActiveDate,
      'familyMembers': familyMembers,
      'createdAt': createdAt.toIso8601String(),
      'subscriptionStartDate': subscriptionStartDate,
      'subscriptionExpiryDate': subscriptionExpiryDate,
      'hasFamilyPremium': hasFamilyPremium,
      'unlockedAchievements': unlockedAchievements,
      'completionDetails': completionDetails,
      'lastSeen': lastSeen,
      'currentActivity': currentActivity,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? selectedLanguage,
    List<String>? interests,
    List<String>? learningGoals,
    List<String>? savedBooks,
    List<String>? completedBooks,
    List<String>? likedBooks,
    Map<String, dynamic>? listeningProgress,
    Map<String, double>? readingProgress,
    String? subscriptionStatus,
    int? streakCount,
    String? lastActiveDate,
    List<String>? familyMembers,
    bool? hasFamilyPremium,
    List<String>? unlockedAchievements,
    Map<String, dynamic>? completionDetails,
    String? subscriptionStartDate,
    String? subscriptionExpiryDate,
    String? lastSeen,
    Map<String, dynamic>? currentActivity,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      interests: interests ?? this.interests,
      learningGoals: learningGoals ?? this.learningGoals,
      savedBooks: savedBooks ?? this.savedBooks,
      completedBooks: completedBooks ?? this.completedBooks,
      likedBooks: likedBooks ?? this.likedBooks,
      listeningProgress: listeningProgress ?? this.listeningProgress,
      readingProgress: readingProgress ?? this.readingProgress,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      streakCount: streakCount ?? this.streakCount,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      familyMembers: familyMembers ?? this.familyMembers,
      createdAt: createdAt,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionExpiryDate: subscriptionExpiryDate ?? this.subscriptionExpiryDate,
      hasFamilyPremium: hasFamilyPremium ?? this.hasFamilyPremium,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      completionDetails: completionDetails ?? this.completionDetails,
      lastSeen: lastSeen ?? this.lastSeen,
      currentActivity: currentActivity ?? this.currentActivity,
    );
  }

  double getBookProgress(Book book, String langCode) {
    // 1. Reading progress
    final double readProgress = readingProgress[book.id] ?? 0.0;
    
    // 2. Listening progress
    double listenProgress = 0.0;
    var progressData = listeningProgress['${book.id}_$langCode'];
    if (progressData == null) {
      final prefix = '${book.id}_';
      final matchingKey = listeningProgress.keys.firstWhere(
        (k) => k.startsWith(prefix),
        orElse: () => '',
      );
      if (matchingKey.isNotEmpty) {
        progressData = listeningProgress[matchingKey];
      }
    }
    if (progressData != null && progressData is Map) {
      final int chapterIndex = progressData['chapterIndex'] ?? 0;
      final chapters = book.getChapterSummaries(langCode);
      if (chapters.isNotEmpty) {
        listenProgress = (chapterIndex / chapters.length).clamp(0.0, 1.0);
      }
    }
    
    final maxProgress = readProgress > listenProgress ? readProgress : listenProgress;
    if (completedBooks.contains(book.id)) {
      return 1.0;
    }
    return maxProgress;
  }
}
