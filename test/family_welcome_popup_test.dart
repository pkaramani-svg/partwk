import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partwk/core/widgets/family_welcome_popup.dart';
import 'package:partwk/core/localization/app_localizations.dart';

class LocalFileSystemAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.json') {
      final manifest = {
        'assets/images/partwk_emblem.png': ['assets/images/partwk_emblem.png'],
      };
      final str = jsonEncode(manifest);
      return ByteData.sublistView(utf8.encode(str));
    }
    if (key == 'AssetManifest.bin') {
      final manifest = {
        'assets/images/partwk_emblem.png': [
          {'asset': 'assets/images/partwk_emblem.png'}
        ],
      };
      final ByteData data = const StandardMessageCodec().encodeMessage(manifest)!;
      return data;
    }
    if (key == 'FontManifest.json') {
      return ByteData.sublistView(utf8.encode('[]'));
    }
    final file = File(key);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      return ByteData.sublistView(bytes);
    }
    return ByteData(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    try {
      final fontFile = File('/System/Library/Fonts/Supplemental/Arial Unicode.ttf');
      if (fontFile.existsSync()) {
        final fontBytes = await fontFile.readAsBytes();
        for (final family in [
          'Roboto',
          'Roboto-Regular',
          'Roboto-Bold',
          'Roboto-Medium',
          'Vazirmatn',
          'Outfit',
        ]) {
          final loader = FontLoader(family);
          loader.addFont(Future.value(ByteData.sublistView(fontBytes)));
          await loader.load();
        }
      }

      final iconFile = File('/Users/peshrawkaramani/Desktop/Partwk/.tool/flutter-3.47.5-stable/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (iconFile.existsSync()) {
        final iconBytes = await iconFile.readAsBytes();
        final iconLoader = FontLoader('MaterialIcons');
        iconLoader.addFont(Future.value(ByteData.sublistView(iconBytes)));
        await iconLoader.load();
      }
    } catch (e) {
      print('Font load error: $e');
    }
  });

  testWidgets('Family Welcome Popup displays canonical partwk_emblem.png and captures screenshot', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(800, 1400); // 400x700 logical
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repaintKey = GlobalKey();

    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: LocalFileSystemAssetBundle(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Roboto',
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFF7B00),
              brightness: Brightness.dark,
            ),
          ),
          supportedLocales: const [Locale('en'), Locale('ku'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizationsDelegate(),
          ],
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: repaintKey,
                child: Builder(
                  builder: (context) {
                    return FamilyWelcomePopup.buildDialogWidget(context, onDismiss: () {});
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify canonical emblem image is rendered
    final imageFinder = find.byType(Image);
    expect(imageFinder, findsOneWidget);
    final Image imageWidget = tester.widget(imageFinder);
    expect((imageWidget.image as AssetImage).assetName, 'assets/images/partwk_emblem.png');

    // Verify dialog content
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Welcome to Partwk Premium'), findsOneWidget);
    expect(find.text('Premium through Family Sharing'), findsOneWidget);

    // Capture screenshot of the Dialog
    await tester.runAsync(() async {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          final artifactDir = Directory('/Users/peshrawkaramani/.gemini/antigravity-ide/brain/b515dc6d-e05e-4d23-9220-75020f850eaf');
          final file = File('${artifactDir.path}/family_welcome_popup_canonical_logo.png');
          await file.writeAsBytes(byteData.buffer.asUint8List());
          print('Captured: family_welcome_popup_canonical_logo.png (${file.lengthSync()} bytes)');
        }
      }
    });
  });
}
