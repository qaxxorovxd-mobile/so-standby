import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/widgets.dart';

class BatteryService extends ChangeNotifier {
  BatteryService() {
    _sub = _battery.onBatteryStateChanged.listen((s) {
      state = s;
      _read();
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _read());
    _read();
  }

  final _battery = Battery();
  StreamSubscription<BatteryState>? _sub;
  Timer? _timer;
  int level = -1;
  BatteryState state = BatteryState.unknown;

  bool get charging => state == BatteryState.charging || state == BatteryState.full;

  Future<void> _read() async {
    try {
      level = await _battery.batteryLevel;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }
}
