import 'dart:io';
import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp, Scaffold;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:so_standby/core/clock.dart';
import 'package:so_standby/core/settings.dart';
import 'package:so_standby/screens/pages.dart';
import 'package:so_standby/screens/settings_sheet.dart';
import 'package:so_standby/widgets/tiles.dart';
import 'package:so_standby/widgets/ios_surface.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_UI')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory('build/ui-review').create(recursive: true);
    await File('build/ui-review/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  // Create the app-wide clock outside FakeAsync; it must outlive widget mounts.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Clock.instance;
    final inter = FontLoader('Inter');
    for (final weight in [400, 500, 600, 700, 800, 900]) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await inter.load();
    await (FontLoader(
      'packages/cupertino_icons/CupertinoIcons',
    )..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'))).load();
  });
  tearDownAll(() => Clock.instance.dispose());

  testWidgets('settings adapt to rotation and keyboard and keep preferences interactive', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    addTearDown(settings.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      SettingsScope(
        settings: settings,
        child: RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF000000),
              body: Builder(
                builder: (context) => CupertinoButton(onPressed: () => showSettingsSheet(context), child: const Text('Open')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text(settings.t.settings), findsOneWidget);
    await capture(tester, 'settings-portrait');
    await tester.tap(find.bySemanticsLabel('${settings.t.accent} 8'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(settings.accent, Accents.blue);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(settings.use24h, isFalse);

    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    }
    await capture(tester, 'settings-landscape');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.scrollUntilVisible(find.byType(CupertinoTextField), 180, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byType(CupertinoTextField));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CupertinoTextField));
    expect(tester.testTextInput.isVisible, isTrue);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await tester.ensureVisible(find.byType(CupertinoTextField));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(tester.getBottomLeft(find.byType(CupertinoTextField)).dy, lessThanOrEqualTo(544));
    expect(tester.takeException(), isNull);
    await capture(tester, 'settings-keyboard');
    await tester.tap(find.text(settings.t.done));
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    expect(find.text('Open'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('split widgets fit portrait and landscape, with reduced motion', (tester) async {
    SharedPreferences.setMockInitialValues({'smoothSeconds': false});
    final settings = await AppSettings.load();
    addTearDown(settings.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in [const Size(390, 844), const Size(844, 390), const Size(320, 568)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        SettingsScope(
          settings: settings,
          child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(size: size, disableAnimations: true),
                  child: const ColoredBox(
                    color: Color(0xFF000000),
                    child: SplitPage(first: AnalogTile(), second: CalendarTile()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
      expect(find.byType(StandbyPanel), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await capture(tester, 'split-${size.width.toInt()}');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
