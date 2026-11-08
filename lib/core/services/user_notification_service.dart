import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_notification.dart';

class UserNotificationService {
  static final UserNotificationService _instance = UserNotificationService._internal();
  factory UserNotificationService() => _instance;
  UserNotificationService._internal();

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  List<UserNotification> _notifications = [];
  String _currentUserId = 'default';
  bool _isInitialized = false;

  List<UserNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> init({String? userId}) async {
    _currentUserId = userId ?? 'default';
    await _loadFromPrefs();
    _isInitialized = true;
  }

  String get _storageKey => 'user_notifications_v1_$_currentUserId';

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _notifications = decoded
            .map((e) => UserNotification.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        _notifications = [];
      }
    } catch (e) {
      debugPrint("UserNotificationService error loading: $e");
      _notifications = [];
    }
    _updateUnreadCount();
  }

  @visibleForTesting
  List<UserNotification> generateSeedNotificationsForTesting(String langCode) {
    final now = DateTime.now();
    if (langCode == 'ku') {
      return [
        UserNotification(
          id: 'welcome_1',
          title: 'بەخێربێیت بۆ پەرتووک!',
          body: 'دەست بکە بە خوێندنەوە و گوێگرتن لە سەدان کورتکراوەی باشترین پەرتووکەکانی جیهان بە زمانی کوردی، عەرەبی و ئینگلیزی.',
          timestamp: now.subtract(const Duration(minutes: 5)),
          isRead: false,
          type: 'welcome',
        ),
        UserNotification(
          id: 'digest_1',
          title: 'پوختەی ڕۆژانەی ئەمڕۆ ئامادەیە',
          body: 'پوختەی تایبەتی ئەمڕۆت بخوێنەوە بۆ گەشەکردنی بەردەوام و پاراستنی زنجیرەی ڕۆژانەت.',
          timestamp: now.subtract(const Duration(hours: 2)),
          isRead: false,
          type: 'digest',
        ),
      ];
    } else if (langCode == 'ar') {
      return [
        UserNotification(
          id: 'welcome_1',
          title: 'مرحباً بك في بارتوك!',
          body: 'ابدأ بالقراءة والاستماع إلى مئات ملخصات أفضل الكتب في العالم باللغات العربية والكردية والإنجليزية.',
          timestamp: now.subtract(const Duration(minutes: 5)),
          isRead: false,
          type: 'welcome',
        ),
        UserNotification(
          id: 'digest_1',
          title: 'الملخص اليومي جاهز لك',
          body: 'اطلع على قراءتك المختارة لليوم لتطوير مهاراتك والحفاظ على سلسلتك التعليمية.',
          timestamp: now.subtract(const Duration(hours: 2)),
          isRead: false,
          type: 'digest',
        ),
      ];
    } else {
      return [
        UserNotification(
          id: 'welcome_1',
          title: 'Welcome to Partwk!',
          body: 'Start reading and listening to hundreds of world-class book summaries in English, Kurdish, and Arabic.',
          timestamp: now.subtract(const Duration(minutes: 5)),
          isRead: false,
          type: 'welcome',
        ),
        UserNotification(
          id: 'digest_1',
          title: 'Daily Digest Ready',
          body: 'Your curated 15-minute summary is ready. Read or listen today to maintain your learning streak!',
          timestamp: now.subtract(const Duration(hours: 2)),
          isRead: false,
          type: 'digest',
        ),
      ];
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint("UserNotificationService error saving: $e");
    }
  }

  void _updateUnreadCount() {
    unreadCountNotifier.value = unreadCount;
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      await _saveToPrefs();
      _updateUnreadCount();
    }
  }

  Future<void> markAllAsRead() async {
    bool hasUnread = _notifications.any((n) => !n.isRead);
    if (hasUnread) {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      await _saveToPrefs();
      _updateUnreadCount();
    }
  }

  Future<void> addNotification(UserNotification notification) async {
    _notifications.insert(0, notification);
    await _saveToPrefs();
    _updateUnreadCount();
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _saveToPrefs();
    _updateUnreadCount();
  }

  // Testing helper for clean deterministic tests
  @visibleForTesting
  void setInitialNotificationsForTesting(List<UserNotification> list) {
    _notifications = List.from(list);
    _updateUnreadCount();
  }

  @visibleForTesting
  void seedForTesting({String langCode = 'en'}) {
    _notifications = generateSeedNotificationsForTesting(langCode);
    _updateUnreadCount();
  }
}
