import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:partwk/main.dart';
import 'package:partwk/core/theme/app_theme.dart';
import 'package:partwk/core/localization/app_localizations.dart';
import 'package:partwk/models/book.dart';
import 'package:partwk/models/category.dart';
import 'package:partwk/services/download_service.dart';

Book _createMockBook({
  required String id,
  required Map<String, String> title,
  Map<String, String> author = const {'en': 'James Clear', 'ku': 'جەیمس کلێر', 'ar': 'جيمس كلير'},
  List<String> categoryIds = const ['cat-productivity'],
  List<String> hiddenLanguages = const [],
}) {
  return Book(
    id: id,
    title: title,
    author: author,
    coverImageUrl: 'https://example.com/cover.jpg',
    categoryIds: categoryIds,
    tags: const [],
    description: const {'en': 'Tiny Changes, Remarkable Results'},
    fiveMinuteSummary: const {},
    fifteenMinuteSummary: const {},
    chapterSummaries: const {},
    keyIdeas: const {},
    keyQuotes: const {},
    actionPoints: const {},
    audioUrl: const {},
    duration: 900,
    isPremium: false,
    isPublished: true,
    hiddenLanguages: hiddenLanguages,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

Widget buildDialogContent({
  required Book book,
  required Category category,
  required String langCode,
}) {
  final isRtl = langCode == 'ku' || langCode == 'ar';
  final categoryName = category.getName(langCode);

  const Map<String, Map<String, String>> strings = {
    'title': {
      'en': 'New Book Available!',
      'ku': 'پەرتووکی نوێ بەردەستە!',
      'ar': 'كتاب جديد متوفر!',
    },
    'by': {
      'en': 'By',
      'ku': 'نووسینی',
      'ar': 'بقلم',
    },
    'category': {
      'en': 'Category',
      'ku': 'پۆل',
      'ar': 'الفئة',
    },
    'languages': {
      'en': 'Languages',
      'ku': 'زمانەکان',
      'ar': 'اللغات',
    },
    'read_listen': {
      'en': 'Read / Listen',
      'ku': 'خوێندنەوە / گوێگرتن',
      'ar': 'قراءة / استماع',
    },
    'close': {
      'en': 'Close',
      'ku': 'داخستن',
      'ar': 'إغلاق',
    },
  };

  String getDialogText(String key) => strings[key]?[langCode] ?? strings[key]?['en'] ?? '';

  final hasEn = book.hasContentForLanguage('en');
  final hasKu = book.hasContentForLanguage('ku');
  final hasAr = book.hasContentForLanguage('ar');
  final availableInAll3 = hasEn && hasKu && hasAr;

  String langInfo;
  if (langCode == 'ku') {
    if (availableInAll3) {
      langInfo = 'بەردەستە بە زمانەکانی کوردی، عەرەبی و ئینگلیزی';
    } else {
      final List<String> langs = [];
      if (hasKu) langs.add('کوردی');
      if (hasAr) langs.add('عەرەبی');
      if (hasEn) langs.add('ئینگلیزی');
      langInfo = 'بەردەستە بە زمانی ${langs.join(' و ')}';
    }
  } else if (langCode == 'ar') {
    if (availableInAll3) {
      langInfo = 'متوفر باللغات الكردية، العربية والإنجليزية';
    } else {
      final List<String> langs = [];
      if (hasKu) langs.add('الكردية');
      if (hasAr) langs.add('العربية');
      if (hasEn) langs.add('الإنجليزية');
      langInfo = 'متوفر باللغة ${langs.join(' و ')}';
    }
  } else {
    if (availableInAll3) {
      langInfo = 'Available in English, Kurdish & Arabic';
    } else {
      final List<String> langs = [];
      if (hasEn) langs.add('English');
      if (hasKu) langs.add('Kurdish');
      if (hasAr) langs.add('Arabic');
      langInfo = 'Available in ${langs.join(', ')}';
    }
  }

  return Scaffold(
    backgroundColor: const Color(0xFF0F172A),
    body: Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // New Book Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Text(
                        getDialogText('title').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.purpleAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Placeholder book cover
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DownloadService.buildCoverPlaceholder(
                          width: 120,
                          height: 180,
                          title: book.getTitle(langCode),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Localized Title
                    Text(
                      book.getTitle(langCode),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),

                    // Author
                    Text(
                      '${getDialogText('by')} ${book.getAuthor(langCode)}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Category
                    if (categoryName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          categoryName,
                          style: const TextStyle(
                            color: Color(0xFF818CF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Languages info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.translate,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            langInfo,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade700),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {},
                            child: Text(
                              getDialogText('close'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            onPressed: () {},
                            child: Text(
                              getDialogText('read_listen'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                right: isRtl ? null : 8,
                left: isRtl ? 8 : null,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.grey,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget wrapWithApp({
  required Widget child,
  required Locale locale,
  required GlobalKey repaintKey,
}) {
  final langState = AppLanguageState();
  langState.setLanguage(locale.languageCode);

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AppLanguageState>.value(value: langState),
      ChangeNotifierProvider<AppThemeProvider>(create: (_) => AppThemeProvider()),
    ],
    child: MaterialApp(
      key: ValueKey('screen_${locale.languageCode}_${repaintKey.hashCode}'),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF4F46E5),
          secondary: Color(0xFF6366F1),
        ),
        textTheme: Typography.material2021().white.apply(
          fontFamily: (locale.languageCode == 'ku' || locale.languageCode == 'ar') ? 'Vazirmatn' : 'Roboto',
        ),
      ),
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
      home: RepaintBoundary(
        key: repaintKey,
        child: child,
      ),
    ),
  );
}

Future<void> saveScreenshot(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(buffer);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final systemFontFile = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
    if (await systemFontFile.exists()) {
      final bytes = await systemFontFile.readAsBytes();
      for (final family in ['Roboto', 'Vazirmatn', 'Outfit', 'Plus Jakarta Sans']) {
        final fontLoader = FontLoader(family);
        fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
        await fontLoader.load();
      }
    }
    final iconFile = File('/Users/peshrawkaramani/Flutter/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (await iconFile.exists()) {
      final bytes = await iconFile.readAsBytes();
      final fontLoader = FontLoader('MaterialIcons');
      fontLoader.addFont(Future.value(ByteData.sublistView(bytes)));
      await fontLoader.load();
    }
  });

  group('Capture New Book Popup Screenshots', () {
    final catProductivity = Category(
      id: 'cat-productivity',
      name: {
        'en': 'Productivity',
        'ku': 'بەرهەمداری',
        'ar': 'الإنتاجية',
      },
      iconName: 'trending-up',
    );

    testWidgets('1. Capture single-language English publication', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bookEnOnly = _createMockBook(
        id: 'atomic-habits',
        title: {'en': 'Atomic Habits'},
      );

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithApp(
          child: buildDialogContent(
            book: bookEnOnly,
            category: catProductivity,
            langCode: 'en',
          ),
          locale: const Locale('en'),
          repaintKey: key,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await saveScreenshot(
        tester,
        key,
        '/Users/peshrawkaramani/Desktop/Partwk/scratch/popup_screenshots/popup_single_language_en.png',
      );
      expect(find.text('Atomic Habits'), findsWidgets);
      expect(find.text('Available in English'), findsOneWidget);
    });

    testWidgets('2. Capture later Kurdish edition publication', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bookWithKurdish = _createMockBook(
        id: 'atomic-habits',
        title: {'en': 'Atomic Habits', 'ku': 'خووە ئەتۆمییەکان'},
      );

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithApp(
          child: buildDialogContent(
            book: bookWithKurdish,
            category: catProductivity,
            langCode: 'ku',
          ),
          locale: const Locale('ku'),
          repaintKey: key,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await saveScreenshot(
        tester,
        key,
        '/Users/peshrawkaramani/Desktop/Partwk/scratch/popup_screenshots/popup_later_edition_ku.png',
      );
      expect(find.text('خووە ئەتۆمییەکان'), findsWidgets);
      expect(find.text('بەردەستە بە زمانی کوردی و ئینگلیزی'), findsOneWidget);
    });

    testWidgets('3. Capture hidden-language exclusion (Kurdish hidden)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final bookKurdishHidden = _createMockBook(
        id: 'atomic-habits',
        title: {'en': 'Atomic Habits', 'ku': 'خووە ئەتۆمییەکان'},
        hiddenLanguages: const ['ku'], // Kurdish hidden
      );

      final key = GlobalKey();
      await tester.pumpWidget(
        wrapWithApp(
          child: buildDialogContent(
            book: bookKurdishHidden,
            category: catProductivity,
            langCode: 'en',
          ),
          locale: const Locale('en'),
          repaintKey: key,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await saveScreenshot(
        tester,
        key,
        '/Users/peshrawkaramani/Desktop/Partwk/scratch/popup_screenshots/popup_hidden_language_excluded_en.png',
      );
      expect(find.text('Atomic Habits'), findsWidgets);
      // Strictly must say "Available in English", never mentioning Kurdish
      expect(find.text('Available in English'), findsOneWidget);
      expect(find.textContaining('Kurdish'), findsNothing);
    });
  });
}
