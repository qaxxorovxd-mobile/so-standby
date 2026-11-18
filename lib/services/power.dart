import 'dart:async';

import 'package:flutter/services.dart';

enum ChargeKind { wired, wireless }

/// Screen edge where the charging port currently is (Type‑C is at the device bottom).
enum PortSide { bottom, right, top, left }

class ChargeEvent {
  const ChargeEvent(this.kind, this.side, this.level);
  final ChargeKind kind;
  final PortSide side;
  final int level;
}

/// Emits a [ChargeEvent] when a charger gets connected while the app is open.
class PowerService {
  PowerService() {
    _sub = _channel.receiveBroadcastStream().listen(_onData, onError: (_) {});
  }

  static const _channel = EventChannel('so_standby/power');
  static const _wireless = 4;

  final _events = StreamController<ChargeEvent>.broadcast();
  StreamSubscription<dynamic>? _sub;
  int? _lastPlugged;
  int level = -1;

  Stream<ChargeEvent> get events => _events.stream;

  void _onData(dynamic data) {
    final m = Map<String, dynamic>.from(data as Map);
    final plugged = (m['plugged'] as num?)?.toInt() ?? 0;
    level = (m['level'] as num?)?.toInt() ?? level;
    final rotation = (m['rotation'] as num?)?.toInt() ?? 0;
    final prev = _lastPlugged;
    _lastPlugged = plugged;
    // Ignore the first (sticky) value: only react to an actual plug-in.
    if (prev == null || prev != 0 || plugged == 0) return;
    final kind = (plugged & _wireless) != 0 ? ChargeKind.wireless : ChargeKind.wired;
    _events.add(ChargeEvent(kind, sideForRotation(rotation), level));
  }

  /// Android Display rotation → edge the device bottom (USB port) is on.
  /// ROTATION_90 means the device was turned counter‑clockwise, so the bottom faces right.
  static PortSide sideForRotation(int rotation) => switch (rotation) {
        1 => PortSide.right,
        2 => PortSide.top,
        3 => PortSide.left,
        _ => PortSide.bottom,
      };

  /// Plays the animation without a real charger (Settings → Preview).
  void simulate(ChargeKind kind, {required bool landscape, int? level}) {
    _events.add(ChargeEvent(kind, landscape ? PortSide.right : PortSide.bottom, level ?? (this.level < 0 ? 76 : this.level)));
  }

  void dispose() {
    _sub?.cancel();
    _events.close();
  }
}
