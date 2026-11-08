import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/localization/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/services/service_locator.dart';
import 'features/auth/splash_screen.dart';
import 'services/notification_service.dart';
import 'features/auth/language_selection_screen.dart';
import 'features/book/summary_completed_popup.dart';
import 'core/services/download_manager.dart';
import 'models/book.dart';
import 'features/book/book_details_screen.dart';
import 'package:app_links/app_links.dart';

// Emulator use is intentionally opt-in at compile time and debug-only. A
// release/profile artifact with this flag refuses to start rather than risking
// a test backend configuration leaking into a distributed build.
const _useFirebaseEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');
const _firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);
const _authEmulatorPort = int.fromEnvironment('FIREBASE_AUTH_EMULATOR_PORT', defaultValue: 19099);
const _firestoreEmulatorPort = int.fromEnvironment('FIREBASE_FIRESTORE_EMULATOR_PORT', defaultValue: 18080);
const _functionsEmulatorPort = int.fromEnvironment('FIREBASE_FUNCTIONS_EMULATOR_PORT', defaultValue: 5001);
const _storageEmulatorPort = int.fromEnvironment('FIREBASE_STORAGE_EMULATOR_PORT', defaultValue: 19199);

class _IsolatedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) => ['127.0.0.1', 'localhost', '10.0.2.2'].contains(uri.host)
        ? 'DIRECT' : 'PROXY 127.0.0.1:9';
    return client;
  }
}

Future<void> _configureDebugFirebaseEmulators() async {
  if (!_useFirebaseEmulators) return;
  if (!kDebugMode) {
    throw StateError('Firebase emulators are permitted only in debug builds.');
  }
  if (_firebaseEmulatorHost != '10.0.2.2' && _firebaseEmulatorHost != '127.0.0.1') {
    throw StateError('Emulator host must be 10.0.2.2 or 127.0.0.1.');
  }
  if (Firebase.app().options.projectId != 'demo-partwk-text') {
    throw StateError('The isolated demo Firebase project is not configured.');
  }
  for (final port in [_authEmulatorPort, _firestoreEmulatorPort, _functionsEmulatorPort, _storageEmulatorPort]) {
    final socket = await Socket.connect(_firebaseEmulatorHost, port, timeout: const Duration(seconds: 2));
    socket.destroy();
  }
  await FirebaseAuth.instance.useAuthEmulator(_firebaseEmulatorHost, _authEmulatorPort, automaticHostMapping: false);
  FirebaseFirestore.instance.useFirestoreEmulator(_firebaseEmulatorHost, _firestoreEmulatorPort, automaticHostMapping: false);
  FirebaseFunctions.instance.useFunctionsEmulator(_firebaseEmulatorHost, _functionsEmulatorPort, automaticHostMapping: false);
  await FirebaseStorage.instance.useStorageEmulator(_firebaseEmulatorHost, _storageEmulatorPort, automaticHostMapping: false);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_useFirebaseEmulators) HttpOverrides.global = _IsolatedHttpOverrides();
  
  // Wipe downloads once for clean testing
  try {
    final prefs = await SharedPreferences.getInstance();
    final hasWiped = prefs.getBool('has_wiped_downloads_v8') ?? false;
    if (!hasWiped) {
      final dir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${dir.path}/books');
      if (await booksDir.exists()) {
        await booksDir.delete(recursive: true);
      }
      await prefs.remove('cached_books_metadata');
      await prefs.setBool('has_wiped_downloads_v8', true);
      print("WIPED ALL DOWNLOADED BOOKS SUCCESSFULLY FOR RESET");
    }
  } catch (e) {
    print("Failed to wipe downloads on start: $e");
  }
  
  // Clean up any sandboxed decrypted temp audio files on startup
  await DownloadManager.cleanupTempPlaybackFiles();
  
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.pkgames.partwk.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );

  // Load environment variables
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Warning: Could not load .env file.");
  }
  
  try {
    await Firebase.initializeApp();
    if (Firebase.app().options.projectId == 'demo-partwk-text' && !_useFirebaseEmulators) {
      throw StateError('The isolated application requires USE_FIREBASE_EMULATORS=true.');
    }
    await _configureDebugFirebaseEmulators();
    if (!_useFirebaseEmulators) await NotificationService().init();
    await AppLocator.init();
  } catch (e) {
    print("Initialization failed: $e");
    if (_useFirebaseEmulators || (Firebase.apps.isNotEmpty && Firebase.app().options.projectId == 'demo-partwk-text')) {
      runApp(MaterialApp(home: Scaffold(body: Center(child: Text('Isolated test configuration failed: $e')))));
      return;
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppLanguageState()),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
      ],
      child: const PartwkApp(),
    ),
  );
}

class FallbackMaterialLocalizationDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';
  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      await GlobalMaterialLocalizations.delegate.load(const Locale('ar'));
  @override
  bool shouldReload(FallbackMaterialLocalizationDelegate old) => false;
}

class FallbackCupertinoLocalizationDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';
  @override
  Future<CupertinoLocalizations> load(Locale locale) async =>
      await GlobalCupertinoLocalizations.delegate.load(const Locale('ar'));
  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FallbackWidgetsLocalizationDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const FallbackWidgetsLocalizationDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ku';
  @override
  Future<WidgetsLocalizations> load(Locale locale) async =>
      await GlobalWidgetsLocalizations.delegate.load(const Locale('ar'));
  @override
  bool shouldReload(FallbackWidgetsLocalizationDelegate old) => false;
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PartwkApp extends StatefulWidget {
  const PartwkApp({Key? key}) : super(key: key);

  @override
  State<PartwkApp> createState() => _PartwkAppState();
}

class _PartwkAppState extends State<PartwkApp> {
  StreamSubscription<Book>? _celebrationSubscription;
  StreamSubscription<void>? _doubleLoginSubscription;
  StreamSubscription<void>? _accountSuspendedSubscription;
  StreamSubscription<Uri>? _linkSubscription;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _celebrationSubscription = AppLocator.auth.completionCelebrationStream.listen((book) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showCompletionCelebrationPopup(context, book);
      }
    });

    _accountSuspendedSubscription = AppLocator.auth.accountSuspendedStream.listen((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final languageState = Provider.of<AppLanguageState>(context, listen: false);
            final langCode = languageState.locale.languageCode;

            final titleStr = langCode == 'ku'
                ? 'هەژماری ڕاگیراو'
                : (langCode == 'ar' ? 'حساب معلق' : 'Account Suspended');
            final descStr = langCode == 'ku'
                ? 'هەژمارەکەت ڕاگیراوە. تکایە پەیوەندی بکە بە پشتگیری لە support@partwk.com.'
                : (langCode == 'ar'
                    ? 'تم تعليق حسابك. يرجى الاتصال بالدعم على support@partwk.com.'
                    : 'Your account has been suspended. Please contact support at support@partwk.com.');
            final btnStr = langCode == 'ku' ? 'باشە' : (langCode == 'ar' ? 'موافق' : 'OK');

            return AlertDialog(
              title: Text(titleStr),
              content: Text(descStr),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
                      (route) => false,
                    );
                  },
                  child: Text(btnStr),
                ),
              ],
            );
          },
        );
      }
    });

    _doubleLoginSubscription = AppLocator.auth.doubleLoginStream.listen((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            final languageState = Provider.of<AppLanguageState>(context, listen: false);
            final langCode = languageState.locale.languageCode;

            final titleStr = langCode == 'ku' ? 'تۆمارکردنێکی تر دۆزرایەوە' : (langCode == 'ar' ? 'تم الكشف عن تسجيل دخول آخر' : 'Session Expired');
            final descStr = langCode == 'ku' ? 'تۆ لە شوێنێکی ترەوە چوویتە ژوورەوە. ئەم ئامێرە دەچێتە دەرەوە.' : (langCode == 'ar' ? 'لقد قمت بتسجيل الدخول من جهاز آخر. سيتم تسجيل خروجك من هذا الجهاز.' : 'You have been signed out because another device logged into your account.');
            final btnStr = langCode == 'ku' ? 'باشە' : (langCode == 'ar' ? 'موافق' : 'OK');

            return AlertDialog(
              title: Text(titleStr),
              content: Text(descStr),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()),
                      (route) => false,
                    );
                  },
                  child: Text(btnStr),
                ),
              ],
            );
          },
        );
      }
    });
  }

  void _initDeepLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      print("Deep link listen error: $err");
    });

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      print("Error getting initial deep link: $e");
    }
  }

  void _handleDeepLink(Uri uri) {
    print("Incoming deep link received: $uri");
    String? bookId;
    
    if (uri.scheme == 'partwk' && uri.host == 'book') {
      if (uri.pathSegments.isNotEmpty) {
        bookId = uri.pathSegments.first;
      } else {
        bookId = uri.queryParameters['id'];
      }
    } else if (uri.host.contains('partwk-bd4ec.web.app') || uri.host.contains('partwk.com') || uri.host.contains('web.app')) {
      final segments = uri.pathSegments;
      final bookIndex = segments.indexOf('book');
      if (bookIndex != -1 && bookIndex + 1 < segments.length) {
        bookId = segments[bookIndex + 1];
      } else {
        bookId = uri.queryParameters['bookId'] ?? uri.queryParameters['id'];
      }
    }

    if (bookId != null && bookId.isNotEmpty) {
      print("Deep linking to book details screen: $bookId");
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => BookDetailsScreen(bookId: bookId!),
        ),
      );
    }
  }

  @override
  void dispose() {
    _celebrationSubscription?.cancel();
    _doubleLoginSubscription?.cancel();
    _accountSuspendedSubscription?.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageState = Provider.of<AppLanguageState>(context);
    final themeState = Provider.of<AppThemeProvider>(context);

    return MaterialApp(
      title: 'Partwk',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: languageState.locale,
      supportedLocales: AppLocalizations.supportedLanguages.map((code) => Locale(code)),
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
        FallbackWidgetsLocalizationDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.getTheme(languageState.locale.languageCode, false), // Light theme
      darkTheme: AppTheme.getTheme(languageState.locale.languageCode, true), // Dark theme
      themeMode: themeState.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
