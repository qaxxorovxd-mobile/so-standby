import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:so_standby/widgets/notification_focus_setup.dart';

void main() {
  const channel = MethodChannel('so_standby/notification_actions');
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  testWidgets('Focus setup opens Android access settings and refreshes after returning', (tester) async {
    var granted = false;
    var opens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'focusStatus') return {'supported': true, 'access': granted, 'state': 'idle'};
      if (call.method == 'openFocusSettings') {
        opens++;
        return true;
      }
      throw MissingPluginException();
    });
    await tester.pumpWidget(const CupertinoApp(home: CupertinoPageScaffold(child: NotificationFocusSetup())));
    await tester.pumpAndSettle();
    expect(find.text('Allow Do Not Disturb access'), findsOneWidget);
    await tester.tap(find.text('StandBy Focus'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Ready for StandBy'), findsOneWidget);
    granted = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Allow Do Not Disturb access'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unsupported Android does not offer an ineffective permission action', (tester) async {
    var opens = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'focusStatus') return {'supported': false, 'access': false, 'state': 'idle'};
      opens++;
      return true;
    });
    await tester.pumpWidget(const CupertinoApp(home: CupertinoPageScaffold(child: NotificationFocusSetup())));
    await tester.pumpAndSettle();
    expect(find.text('Requires Android 10 or later'), findsOneWidget);
    expect(tester.widget<CupertinoButton>(find.byType(CupertinoButton)).onPressed, isNull);
    expect(opens, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
