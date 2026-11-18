import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

enum NightMode { off, auto, on }

/// Apple system colors (dark appearance).
class Accents {
  static const white = Color(0xFFFFFFFF);
  static const red = Color(0xFFFF453A);
  static const orange = Color(0xFFFF9F0A);
  static const yellow = Color(0xFFFFD60A);
  static const green = Color(0xFF30D158);
  static const mint = Color(0xFF63E6E2);
  static const cyan = Color(0xFF64D2FF);
  static const blue = Color(0xFF0A84FF);
  static const indigo = Color(0xFF5E5CE6);
  static const purple = Color(0xFFBF5AF2);
  static const pink = Color(0xFFFF375F);

  static const all = [white, red, orange, yellow, green, mint, cyan, blue, indigo, purple, pink];
}

class AppSettings extends ChangeNotifier {
  AppSettings._(this._p);
  final SharedPreferences _p;

  static Future<AppSettings> load() async => AppSettings._(await SharedPreferences.getInstance());

  bool get onboarded => _p.getBool('onboarded') ?? false;
  set onboarded(bool v) => _set('onboarded', v);

  /// The app ships in English only.
  AppLang get lang => AppLang.en;
  set lang(AppLang v) => _set('lang', v.index);
  L10n get t => L10n(lang);

  Color get accent => Color(_p.getInt('accent') ?? Accents.orange.toARGB32());
  set accent(Color c) => _set('accent', c.toARGB32());

  bool get use24h => _p.getBool('use24h') ?? true;
  set use24h(bool v) => _set('use24h', v);

  bool get showSeconds => _p.getBool('showSeconds') ?? false;
  set showSeconds(bool v) => _set('showSeconds', v);

  bool get smoothSeconds => _p.getBool('smoothSeconds') ?? true;
  set smoothSeconds(bool v) => _set('smoothSeconds', v);

  NightMode get nightMode => NightMode.values[(_p.getInt('night') ?? 1).clamp(0, 2)];
  set nightMode(NightMode v) => _set('night', v.index);

  bool get fahrenheit => _p.getBool('fahrenheit') ?? false;
  set fahrenheit(bool v) => _set('fahrenheit', v);

  bool get keepAwake => _p.getBool('keepAwake') ?? true;
  set keepAwake(bool v) => _set('keepAwake', v);

  bool get burnIn => _p.getBool('burnIn') ?? true;
  set burnIn(bool v) => _set('burnIn', v);

  /// Manual city (null => use device location).
  String? get manualCity => _p.getString('city');
  double? get manualLat => _p.getDouble('cityLat');
  double? get manualLon => _p.getDouble('cityLon');
  Future<void> setManualCity(String? name, double? lat, double? lon) async {
    if (name == null) {
      await _p.remove('city');
      await _p.remove('cityLat');
      await _p.remove('cityLon');
    } else {
      await _p.setString('city', name);
      await _p.setDouble('cityLat', lat!);
      await _p.setDouble('cityLon', lon!);
    }
    notifyListeners();
  }

  int get lastPage => _p.getInt('page') ?? 0;
  set lastPage(int v) => _p.setInt('page', v);
  int get clockStyle => _p.getInt('clockStyle') ?? 0;
  set clockStyle(int v) => _p.setInt('clockStyle', v);

  String? getString(String k) => _p.getString(k);
  Future<void> setString(String k, String v) => _p.setString(k, v);

  void _set(String key, Object v) {
    switch (v) {
      case bool b:
        _p.setBool(key, b);
      case int i:
        _p.setInt(key, i);
      case String s:
        _p.setString(key, s);
    }
    notifyListeners();
  }
}

/// InheritedNotifier giving every widget cheap access to settings.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child}) : super(notifier: settings);

  static AppSettings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()!.notifier!;

  /// Non-subscribing lookup (safe in initState).
  static AppSettings read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()!.notifier!;
}
