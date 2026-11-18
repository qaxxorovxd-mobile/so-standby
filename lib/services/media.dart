import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class NowPlaying {
  const NowPlaying({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.position,
    required this.playing,
    required this.app,
    required this.package,
    this.art,
  });

  final String title, artist, album, app, package;
  final int duration, position;
  final bool playing;
  final Uint8List? art;

  String get key => '$package|$title|$artist|$album';
  double get progress => duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0;
}

/// Bridges Android MediaSession (via NotificationListener access) to Flutter.
class MediaService extends ChangeNotifier {
  static const _ch = MethodChannel('so_standby/media');

  bool hasAccess = false;
  NowPlaying? current;
  Timer? _poll;
  int _listeners = 0;
  String? _artKey;
  Uint8List? _art;

  /// Starts polling while at least one media view is visible.
  void attach() {
    _listeners++;
    _poll ??= Timer.periodic(const Duration(milliseconds: 900), (_) => _tick());
    _tick();
  }

  void detach() {
    _listeners = (_listeners - 1).clamp(0, 99);
    if (_listeners == 0) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<bool> checkAccess() async {
    try {
      hasAccess = await _ch.invokeMethod<bool>('hasAccess') ?? false;
    } catch (_) {
      hasAccess = false;
    }
    notifyListeners();
    return hasAccess;
  }

  Future<void> openAccessSettings() async {
    try {
      await _ch.invokeMethod('openAccessSettings');
    } catch (_) {}
  }

  Future<void> _tick() async {
    try {
      final access = await _ch.invokeMethod<bool>('hasAccess') ?? false;
      if (access != hasAccess) {
        hasAccess = access;
      }
      if (!access) {
        if (current != null) current = null;
        notifyListeners();
        return;
      }
      final first = await _ch.invokeMapMethod<String, dynamic>('nowPlaying', {'art': false});
      if (first == null) {
        current = null;
        notifyListeners();
        return;
      }
      final key = '${first['package']}|${first['title']}|${first['artist']}|${first['album']}';
      if (key != _artKey) {
        final withArt = await _ch.invokeMapMethod<String, dynamic>('nowPlaying', {'art': true});
        _art = withArt?['art'] as Uint8List?;
        _artKey = key;
      }
      current = NowPlaying(
        title: first['title'] ?? '',
        artist: first['artist'] ?? '',
        album: first['album'] ?? '',
        duration: (first['duration'] as num?)?.toInt() ?? 0,
        position: (first['position'] as num?)?.toInt() ?? 0,
        playing: first['playing'] == true,
        app: first['app'] ?? '',
        package: first['package'] ?? '',
        art: _art,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> command(String cmd, {int? pos}) async {
    HapticFeedback.lightImpact();
    try {
      await _ch.invokeMethod('command', {'cmd': cmd, 'pos': ?pos});
    } catch (_) {}
    Future.delayed(const Duration(milliseconds: 250), _tick);
  }

  Future<void> openPlayer() async {
    try {
      await _ch.invokeMethod('openPlayer');
    } catch (_) {}
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
