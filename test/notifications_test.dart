import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_standby/core/style.dart';
import 'package:so_standby/services/notifications.dart';
import 'package:so_standby/widgets/notification_banner.dart';

import 'ui_layout_test.dart' show capture;

StandbyNotice notice(String key, {String body = 'I will be there in ten minutes.', DateTime? at}) =>
    StandbyNotice(key: key, app: 'Messages', title: 'Alex', body: body, receivedAt: at, canOpen: true);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final inter = FontLoader('Inter');
    for (final weight in [400, 500, 600, 700]) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await inter.load();
    await (FontLoader(
      'packages/cupertino_icons/CupertinoIcons',
    )..addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'))).load();
  });

  test('queue coalesces, bounds bursts, removes withdrawn notifications and expires old messages', () {
    final queue = NoticeQueue();
    addTearDown(queue.dispose);
    queue.add(notice('first'));
    queue.add(notice('first', body: 'Updated message'));
    expect(queue.current!.body, 'Updated message');
    expect(queue.pendingCount, 0);
    for (var i = 0; i < 5; i++) {
      queue.add(notice('$i'));
    }
    expect(queue.pendingCount, 3);
    queue.remove('3');
    queue.advance();
    expect(queue.current!.key, '2');
    queue.add(notice('stale', at: DateTime.now().subtract(const Duration(minutes: 1))));
    queue.advance();
    expect(queue.current!.key, '4');
    queue.advance();
    expect(queue.current, isNull);
    queue.add(notice('clear'));
    queue.clear();
    expect(queue.current, isNull);
    expect(queue.pendingCount, 0);
  });

  testWidgets('banner animates without overflow, opens only on tap and dismisses once', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var dismissed = 0;
    var opened = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: ColoredBox(
              color: Palette.bg,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: NotificationBanner(
                      notice: notice('one'),
                      accent: Palette.blue,
                      onDismiss: () => dismissed++,
                      onOpen: () async {
                        opened++;
                        return true;
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      expect(tester.takeException(), isNull);
    }
    await capture(tester, 'notification-portrait');
    expect(opened, 0);
    await tester.tap(find.text('Alex'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(opened, 1);
    expect(dismissed, 1);
    await tester.pump(const Duration(seconds: 8));
    expect(dismissed, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('banner respects reduced motion, night mode and swipe dismissal on narrow screens', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      var dismissed = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: RepaintBoundary(
              key: const ValueKey('capture'),
              child: ColoredBox(
                color: Palette.bg,
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: NotificationBanner(
                        key: ValueKey(size),
                        notice: notice('night', body: 'A longer message that should wrap gracefully across two lines without overflowing.'),
                        accent: Palette.blue,
                        night: true,
                        pendingCount: 3,
                        onDismiss: () => dismissed++,
                        onOpen: () async => false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await capture(tester, 'notification-night-${size.width.toInt()}');
      await tester.drag(find.text('Alex'), const Offset(0, -60));
      await tester.pump();
      expect(dismissed, 1);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('banner times out and its timer is cancelled on unmount', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: NotificationBanner(
            notice: notice('timeout'),
            accent: Palette.blue,
            onDismiss: () => dismissed++,
            onOpen: () async => false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(dismissed, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(dismissed, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    expect(dismissed, 1);
  });
}
