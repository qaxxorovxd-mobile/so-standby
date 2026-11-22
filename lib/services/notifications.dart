import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class StandbyNotice {
  StandbyNotice({
    required this.key,
    required this.app,
    required this.title,
    required this.body,
    this.icon,
    this.canOpen = false,
    this.redacted = false,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  final String key, app, title, body;
  final Uint8List? icon;
  final bool canOpen, redacted;
  final DateTime receivedAt;

  factory StandbyNotice.fromMap(Map<Object?, Object?> data) => StandbyNotice(
    key: data['key'] as String? ?? '',
    app: data['app'] as String? ?? 'Notification',
    title: data['title'] as String? ?? 'New notification',
    body: data['body'] as String? ?? '',
    icon: data['icon'] is Uint8List ? data['icon'] as Uint8List : null,
    canOpen: data['canOpen'] == true,
    redacted: data['redacted'] == true,
  );

  static StandbyNotice preview() => StandbyNotice(
    key: 'standby-preview',
    app: 'So StandBy',
    title: 'A little hello.',
    body: 'Your notifications, beautifully at a glance. Swipe to dismiss.',
  );
}

/// Ephemeral, bounded queue. Repeated updates replace a card rather than stack it.
class NoticeQueue extends ChangeNotifier {
  final List<StandbyNotice> _pending = [];
  StandbyNotice? _current;
  StandbyNotice? get current => _current;
  int get pendingCount => _pending.length;

  void add(StandbyNotice notice) {
    if (notice.key.isEmpty) return;
    if (_current?.key == notice.key) {
      if (_current!.title == notice.title && _current!.body == notice.body && _current!.redacted == notice.redacted) return;
      _current = notice;
    } else if (_current == null) {
      _current = notice;
    } else {
      _pending.removeWhere((n) => n.key == notice.key);
      if (_pending.length == 3) _pending.removeAt(0);
      _pending.add(notice);
    }
    notifyListeners();
  }

  void remove(String key) {
    _pending.removeWhere((n) => n.key == key);
    if (_current?.key == key) {
      advance();
    } else {
      notifyListeners();
    }
  }

  void advance() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 25));
    _pending.removeWhere((n) => n.receivedAt.isBefore(cutoff));
    _current = _pending.isEmpty ? null : _pending.removeAt(0);
    notifyListeners();
  }

  void clear() {
    if (_current == null && _pending.isEmpty) return;
    _current = null;
    _pending.clear();
    notifyListeners();
  }
}

class NotificationService {
  static const _events = EventChannel('so_standby/notifications');
  static const _actions = MethodChannel('so_standby/notification_actions');
  StreamSubscription<dynamic>? _subscription;

  static Future<NotificationFocusStatus> focusStatus() async {
    try {
      final data = await _actions.invokeMapMethod<String, dynamic>('focusStatus');
      return NotificationFocusStatus(
        supported: data?['supported'] == true,
        access: data?['access'] == true,
        state: data?['state'] as String? ?? 'idle',
      );
    } on PlatformException catch (_) {
      return const NotificationFocusStatus();
    } on MissingPluginException catch (_) {
      return const NotificationFocusStatus();
    }
  }

  static Future<bool> openFocusSettings() async {
    try {
      return await _actions.invokeMethod<bool>('openFocusSettings') ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  void listen(void Function(Map<Object?, Object?> event) onEvent) {
    _subscription = _events.receiveBroadcastStream().listen((event) {
      if (event is Map) onEvent(Map<Object?, Object?>.from(event));
    }, onError: (_) => onEvent({'type': 'clear'}));
  }

  Future<void> configure({required bool enabled, required bool previews}) async {
    try {
      await _actions.invokeMethod<void>('configure', {'enabled': enabled, 'previews': previews});
    } on PlatformException catch (_) {
    } on MissingPluginException catch (_) {}
  }

  Future<bool> open(String key) async {
    try {
      return await _actions.invokeMethod<bool>('open', {'key': key}) ?? false;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException catch (_) {
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    unawaited(configure(enabled: false, previews: false));
  }
}

class NotificationFocusStatus {
  const NotificationFocusStatus({this.supported = false, this.access = false, this.state = 'idle'});
  final bool supported, access;
  final String state;

  String get label {
    if (!supported) return 'Requires Android 10 or later';
    if (!access) return 'Allow Do Not Disturb access';
    return switch (state) {
      'active' => 'Active in StandBy',
      'otherDnd' => 'Paused by another Do Not Disturb mode',
      'error' => 'Could not start. Check Android settings',
      _ => 'Ready for StandBy',
    };
  }
}
