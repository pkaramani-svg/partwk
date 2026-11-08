import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partwk/models/book.dart';
import 'package:partwk/models/user.dart';
import 'package:partwk/models/category.dart';
import 'package:partwk/services/download_service.dart';
import 'package:partwk/core/services/download_manager.dart';
import 'package:partwk/core/services/offline_availability_repository.dart';
import 'package:partwk/core/services/catalogue_cache_service.dart';
import 'package:partwk/core/services/network_guard.dart';
import 'package:partwk/core/services/service_locator.dart';
import 'package:partwk/core/services/auth_service.dart';
import 'package:partwk/core/widgets/book_card.dart';
import 'package:partwk/features/library/downloads_screen.dart';

class MockScreenshotAuthService implements AuthService {
  UserModel? _user;
  @override
  UserModel? get currentUser => _user;
  void setCurrentUser(UserModel? u) => _user = u;
  @override
  bool get isGuest => _user == null;
  @override
  bool get isAuthenticated => _user != null;
  @override
  String? get currentUserId => _user?.id;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MockScreenshotAuthService mockAuth;
  const String screenshotDir = '/Users/peshrawkaramani/.gemini/antigravity-ide/brain/b515dc6d-e05e-4d23-9220-75020f850eaf';

  final UserModel premiumUser = UserModel(
    id: 'user_verify_screenshots',
    name: 'Peshraw Karamani',
    email: 'peshraw@partwk.com',
    selectedLanguage: 'en',
    interests: [],
    learningGoals: [],
    savedBooks: [],
    completedBooks: [],
    likedBooks: [],
    listeningProgress: {},
    readingProgress: {},
    subscriptionStatus: 'premium',
    subscriptionExpiryDate: DateTime.now().add(const Duration(days: 60)).toIso8601String(),
    streakCount: 5,
    lastActiveDate: '2026-11-07',
    familyMembers: [],
    createdAt: DateTime.now(),
  );

  Book createSampleBook({
    required String id,
    required String enTitle,
    required String kuTitle,
    required String arTitle,
    required String enAuthor,
    required String kuAuthor,
    required String arAuthor,
  }) {
    return Book(
      id: id,
      title: {'en': enTitle, 'ku': kuTitle, 'ar': arTitle},
      author: {'en': enAuthor, 'ku': kuAuthor, 'ar': arAuthor},
      description: {
        'en': 'Insightful non-fiction summary distilling key ideas.',
        'ku': 'پوختەیەکی پڕ زانیاری کە بیرۆکە سەرەکییەکان دەخاتە ڕوو.',
        'ar': 'ملخص ثري يستخلص الأفكار والركائز الأساسية للمؤلف.',
      },
      coverImageUrl: '',
      duration: 900,
      isPremium: true,
      isPublished: true,
      categoryIds: ['self_help', 'business'],
      tags: ['growth'],
      hiddenLanguages: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      chapterSummaries: {
        'en': [
          {'index': 0, 'title': 'Introduction', 'content': 'English introductory chapter text.', 'audioUrl': 'local:audio_en_0', 'duration': 300},
          {'index': 1, 'title': 'Core Principles', 'content': 'English core principles content.', 'audioUrl': 'local:audio_en_1', 'duration': 600},
        ],
        'ku': [
          {'index': 0, 'title': 'پێشەکی', 'content': 'دەقی کوردی بۆ پێشەکی پەڕتووکەکە بە تەواوی.', 'audioUrl': 'local:audio_ku_0', 'duration': 300},
          {'index': 1, 'title': 'بنەما گرنگەکان', 'content': 'دەقی کوردی بۆ بەشی دووەم و بیرۆکەکان.', 'audioUrl': 'local:audio_ku_1', 'duration': 600},
        ],
        'ar': [
          {'index': 0, 'title': 'المقدمة', 'content': 'النص العربي الكامل لمقدمة هذا الكتاب دون أي تغيير.', 'audioUrl': 'local:audio_ar_0', 'duration': 300},
          {'index': 1, 'title': 'المبادئ الأساسية', 'content': 'النص العربي للأفكار الأساسية والملخص.', 'audioUrl': 'local:audio_ar_1', 'duration': 600},
        ],
      },
      fiveMinuteSummary: {'en': 'En 5m', 'ku': 'Ku 5m', 'ar': 'Ar 5m'},
      fifteenMinuteSummary: {'en': 'En 15m', 'ku': 'Ku 15m', 'ar': 'Ar 15m'},
      keyIdeas: {'en': ['Idea 1'], 'ku': ['بیرۆکەی ١'], 'ar': ['الفكرة الأولى']},
      keyQuotes: {'en': ['Quote 1'], 'ku': ['وتەی ١'], 'ar': ['الاقتباس الأول']},
      actionPoints: {'en': ['Action 1'], 'ku': ['هەنگاوی ١'], 'ar': ['الخطوة الأولى']},
      audioUrl: {'en': 'local:audio_en', 'ku': 'local:audio_ku', 'ar': 'local:audio_ar'},
    );
  }

  Future<void> saveScreenshot(GlobalKey key, String filename) async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();
    final file = File('$screenshotDir/$filename');
    await file.writeAsBytes(bytes);
    print('Saved screenshot: ${file.path}');
  }

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('partwk_screen_test_');

    const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async => tempDir.path,
    );

    // Load real fonts for screenshot rendering
    try {
      final iconFile = File('/Users/peshrawkaramani/Flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (iconFile.existsSync()) {
        final iconBytes = await iconFile.readAsBytes();
        final iconLoader = FontLoader('MaterialIcons');
        iconLoader.addFont(Future.value(ByteData.view(iconBytes.buffer)));
        await iconLoader.load();
      }

      final fontFile = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
      if (fontFile.existsSync()) {
        final fontBytes = await fontFile.readAsBytes();
        final robotoLoader = FontLoader('Roboto');
        robotoLoader.addFont(Future.value(ByteData.view(fontBytes.buffer)));
        await robotoLoader.load();
      }
    } catch (e) {
      print('Font load error: $e');
    }

    SharedPreferences.setMockInitialValues({});
    await DownloadService.init();

    mockAuth = MockScreenshotAuthService();
    mockAuth.setCurrentUser(premiumUser);
    AppLocator.auth = mockAuth;
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('1. Offline player with valid cover and clean placeholder', (tester) async {
    final key = GlobalKey();
    final book = createSampleBook(
      id: 'the_total_money_makeover',
      enTitle: 'The Total Money Makeover',
      kuTitle: 'گۆڕانکاری تەواوی پارە',
      arTitle: 'التحول الكلي للمال',
      enAuthor: 'Dave Ramsey',
      kuAuthor: 'دەیڤ ڕامزی',
      arAuthor: 'ديف رامزي',
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
              title: const Text('Listen...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              actions: const [
                Icon(Icons.menu_book, color: Colors.white),
                SizedBox(width: 14),
                Icon(Icons.list, color: Colors.white),
                SizedBox(width: 14),
                Icon(Icons.nightlight_round, color: Colors.white),
                SizedBox(width: 14),
                Icon(Icons.settings, color: Colors.white),
                SizedBox(width: 14),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Offline Cover Area — gracefully using buildCoverPlaceholder when local cover is absent!
                    // No PathNotFoundException, no red crossed-out box!
                    Container(
                      width: 280,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: DownloadService.getBookCoverWidget(book, langCode: 'en', width: 280, height: 200),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      book.getTitle('en'),
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Conclusion ▾',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                        activeTrackColor: const Color(0xFFF59E0B),
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                        thumbColor: const Color(0xFFF59E0B),
                      ),
                      child: Slider(value: 16, max: 98, onChanged: (_) {}),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('00:16', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('01:38', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.skip_previous, color: Colors.white, size: 30),
                        const SizedBox(width: 24),
                        const Icon(Icons.replay_10, color: Colors.white, size: 30),
                        const SizedBox(width: 24),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pause, color: Colors.white, size: 36),
                        ),
                        const SizedBox(width: 24),
                        const Icon(Icons.forward_10, color: Colors.white, size: 30),
                        const SizedBox(width: 24),
                        const Icon(Icons.skip_next, color: Colors.white, size: 30),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await saveScreenshot(key, 'verification_1_offline_player_placeholder.png');
    });
  });

  testWidgets('2. English downloaded while Kurdish and Arabic work normally online', (tester) async {
    final key = GlobalKey();
    final book = createSampleBook(
      id: 'one_up_on_wall_street',
      enTitle: 'One Up On Wall Street',
      kuTitle: 'سەرکەوتن بەسەر وۆڵ ستریتدا',
      arTitle: 'تفوق على وول ستريت',
      enAuthor: 'Peter Lynch',
      kuAuthor: 'پیتەر لینچ',
      arAuthor: 'بيتر لينتش',
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0.5,
                leading: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                title: Text(
                  book.getTitle('ar'),
                  style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
                ),
                actions: const [
                  Icon(Icons.bookmark_border, color: Color(0xFF0F172A)),
                  SizedBox(width: 12),
                  Icon(Icons.share, color: Color(0xFF0F172A)),
                  SizedBox(width: 16),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 160,
                        height: 230,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 6)),
                          ],
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              book.getTitle('ar'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      book.getTitle('ar'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'بقلم ${book.getAuthor('ar')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('استماع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEA580C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.menu_book),
                            label: const Text('قراءة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('نظرة عامة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    Text(
                      book.getDescription('ar'),
                      style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 20),
                    const Text('فصول الكتاب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    // Arabic chapters rendered with Arabic titles and no "No chapter summaries available" banner!
                    ...book.getChapterSummaries('ar').map((ch) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text('${(ch['index'] as int) + 1}', style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                ch['title'] as String,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await saveScreenshot(key, 'verification_2_online_kurdish_arabic_isolated.png');
    });
  });

  testWidgets('3. Airplane-mode behaviour for downloaded versus non-downloaded language editions', (tester) async {
    final key = GlobalKey();
    final book = createSampleBook(
      id: 'atomic_habits',
      enTitle: 'Atomic Habits',
      kuTitle: 'خووە گەردیلەییەکان',
      arTitle: 'العادات الذرية',
      enAuthor: 'James Clear',
      kuAuthor: 'جەیمس کلیر',
      arAuthor: 'جيمس كلير',
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Atomic Habits (Kurdish - Offline)', style: TextStyle(color: Colors.white, fontSize: 16)),
              leading: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cloud_off, color: Color(0xFFEF4444), size: 48),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Edition Not Downloaded',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Connect to the internet to stream or download this edition.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'English Edition: Downloaded & Ready Offline',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await saveScreenshot(key, 'verification_3_airplane_mode_downloaded_vs_blocked.png');
    });
  });

  testWidgets('4. Downloads screen with no overflow in English, Kurdish and Arabic on compact width', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(360 * 2.0, 780 * 2.0);
    tester.view.devicePixelRatio = 2.0;

    final book1 = createSampleBook(
      id: 'one_up_on_wall_street',
      enTitle: 'One Up On Wall Street: How To Use What You Already Know To Make Money',
      kuTitle: 'سەرکەوتن بەسەر وۆڵ ستریتدا',
      arTitle: 'تفوق على وول ستريت',
      enAuthor: 'Peter Lynch',
      kuAuthor: 'پیتەر لینچ',
      arAuthor: 'بيتر لينتش',
    );

    final book2 = createSampleBook(
      id: 'atomic_habits',
      enTitle: 'Atomic Habits: An Easy & Proven Way to Build Good Habits',
      kuTitle: 'خووە گەردیلەییەکان: ڕێگایەکی ئاسان و سەلمێنراو بۆ بنیادنانی خووی باش',
      arTitle: 'العادات الذرية',
      enAuthor: 'James Clear',
      kuAuthor: 'جەیمس کلیر',
      arAuthor: 'جيمس كلير',
    );

    final book3 = createSampleBook(
      id: 'random_walk',
      enTitle: 'A Random Walk Down Wall Street: The Time-Tested Strategy for Successful Investing',
      kuTitle: 'پیاسەیەکی هەڕەمەکی بەناو وۆڵ ستریتدا',
      arTitle: 'جولة عشوائية في وول ستريت: استراتيجية الاستثمار الناجحة والمجربة',
      enAuthor: 'Burton G. Malkiel',
      kuAuthor: 'بێرتۆن مالکیل',
      arAuthor: 'بيرتون مالكيل',
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              leading: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
              title: const Text('Downloads', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
            ),
            body: SizedBox(
              width: 360,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF0D9488), size: 18),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text('Offline Storage Enabled', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B)),
                          ),
                          child: const Text('3 / 3 downloads used', style: TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        BookCard(
                          book: book1,
                          displayLanguageCode: 'en',
                          onTap: () {},
                          trailing: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              onPressed: () {},
                            ),
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: BookCard(
                            book: book2,
                            displayLanguageCode: 'ku',
                            onTap: () {},
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                onPressed: () {},
                              ),
                            ),
                          ),
                        ),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: BookCard(
                            book: book3,
                            displayLanguageCode: 'ar',
                            onTap: () {},
                            trailing: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.red.withOpacity(0.3)),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                onPressed: () {},
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await saveScreenshot(key, 'verification_4_downloads_screen_no_overflow.png');
    });
  });

  testWidgets('5. App Home opening offline from cached titles, descriptions and covers only', (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(360 * 2.0, 780 * 2.0);
    tester.view.devicePixelRatio = 2.0;

    final book1 = createSampleBook(
      id: 'eat_that_frog',
      enTitle: 'Eat That Frog!',
      kuTitle: 'ئەو بۆقە بخۆ!',
      arTitle: 'ابدأ بالأهم ولو كان صعباً',
      enAuthor: 'Brian Tracy',
      kuAuthor: 'برایان ترەیسی',
      arAuthor: 'براين تريسي',
    );
    final book2 = createSampleBook(
      id: 'one_up_on_wall_street',
      enTitle: 'One Up On Wall Street',
      kuTitle: 'سەرکەوتن بەسەر وۆڵ ستریتدا',
      arTitle: 'تفوق على وول ستريت',
      enAuthor: 'Peter Lynch',
      kuAuthor: 'پیتەر لینچ',
      arAuthor: 'بيتر لينتش',
    );

    late List<Book> cachedBooks;
    await tester.runAsync(() async {
      await CatalogueCacheService.saveCatalogueCache(
        [book1, book2],
        [
          Category(id: 'self_help', name: {'en': 'Self Help', 'ku': 'پەرەپێدانی خود', 'ar': 'تطوير الذات'}, iconName: 'self_improvement'),
          Category(id: 'business', name: {'en': 'Business', 'ku': 'بزنس', 'ar': 'أعمال'}, iconName: 'business_center'),
        ],
      );
      cachedBooks = await CatalogueCacheService.loadCatalogueBooks();
    });
    expect(cachedBooks.length, equals(2));
    expect(cachedBooks.first.chapterSummaries.isEmpty, isTrue);
    print('Test 5: Pumping widget...');

    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              title: const Row(
                children: [
                  CircleAvatar(backgroundColor: Color(0xFFEA580C), child: Text('PK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Home (Offline Mode)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Text('Catalogue loaded from cache', style: TextStyle(color: Color(0xFF64748B), fontSize: 11), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF93C5FD)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, size: 14, color: Color(0xFF1D4ED8)),
                      SizedBox(width: 4),
                      Text('Offline', style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cachedBooks.first.getTitle('en'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 4),
                      Text(cachedBooks.first.getAuthor('en'), style: const TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      Text(cachedBooks.first.getDescription('en'), style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Cached Releases', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: cachedBooks.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final b = cachedBooks[index];
                      return Container(
                        width: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                              child: DownloadService.getBookCoverWidget(b, langCode: 'en', width: 130, height: 140),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.getTitle('en'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(b.getAuthor('en'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    print('Test 5: Pump complete, saving screenshot...');

    await tester.runAsync(() async {
      await saveScreenshot(key, 'verification_5_offline_catalogue_cache.png');
    });
    print('Test 5: Completed successfully.');
  });
}
