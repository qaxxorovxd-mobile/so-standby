import 'dart:async';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../core/settings.dart';

class HourForecast {
  const HourForecast(this.time, this.temp, this.code, this.isDay);
  final DateTime time;
  final double temp;
  final int code;
  final bool isDay;

  Map<String, dynamic> toJson() => {'t': time.toIso8601String(), 'temp': temp, 'c': code, 'd': isDay};
  factory HourForecast.fromJson(Map<String, dynamic> j) =>
      HourForecast(DateTime.parse(j['t']), (j['temp'] as num).toDouble(), j['c'], j['d']);
}

class WeatherData {
  const WeatherData({
    required this.city,
    required this.temp,
    required this.code,
    required this.isDay,
    required this.high,
    required this.low,
    required this.hours,
    required this.fetchedAt,
    required this.fahrenheit,
  });

  final String city;
  final double temp;
  final int code;
  final bool isDay;
  final double high;
  final double low;
  final List<HourForecast> hours;
  final DateTime fetchedAt;
  final bool fahrenheit;

  Map<String, dynamic> toJson() => {
        'city': city,
        'temp': temp,
        'code': code,
        'isDay': isDay,
        'high': high,
        'low': low,
        'hours': hours.map((e) => e.toJson()).toList(),
        'at': fetchedAt.toIso8601String(),
        'f': fahrenheit,
      };

  factory WeatherData.fromJson(Map<String, dynamic> j) => WeatherData(
        city: j['city'],
        temp: (j['temp'] as num).toDouble(),
        code: j['code'],
        isDay: j['isDay'],
        high: (j['high'] as num).toDouble(),
        low: (j['low'] as num).toDouble(),
        hours: (j['hours'] as List).map((e) => HourForecast.fromJson(e)).toList(),
        fetchedAt: DateTime.parse(j['at']),
        fahrenheit: j['f'] ?? false,
      );
}

enum WeatherStatus { idle, loading, ready, noPermission, error }

IconData weatherIcon(int code, {bool isDay = true}) {
  if (code == 0) return isDay ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill;
  if (code == 1 || code == 2) return isDay ? CupertinoIcons.cloud_sun_fill : CupertinoIcons.cloud_moon_fill;
  if (code == 3) return CupertinoIcons.cloud_fill;
  if (code == 45 || code == 48) return CupertinoIcons.cloud_fog_fill;
  if (code >= 51 && code <= 57) return CupertinoIcons.cloud_drizzle_fill;
  if (code == 65 || code == 67 || code == 82) return CupertinoIcons.cloud_heavyrain_fill;
  if (code >= 61 && code <= 67) return CupertinoIcons.cloud_rain_fill;
  if (code >= 80 && code <= 81) return CupertinoIcons.cloud_rain_fill;
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return CupertinoIcons.cloud_snow_fill;
  if (code == 95) return CupertinoIcons.cloud_bolt_rain_fill;
  if (code == 96 || code == 99) return CupertinoIcons.cloud_hail_fill;
  return CupertinoIcons.cloud_fill;
}

Color weatherIconColor(int code, {bool isDay = true}) =>
    (code == 0 && isDay) ? const Color(0xFFFFD60A) : const Color(0xFFFFFFFF);

class WeatherService extends ChangeNotifier {
  WeatherService(this.settings) {
    final cached = settings.getString('weatherCache');
    if (cached != null) {
      try {
        data = WeatherData.fromJson(jsonDecode(cached));
        status = WeatherStatus.ready;
      } catch (_) {}
    }
    settings.addListener(_onSettings);
    _lastUnitF = settings.fahrenheit;
    _lastCity = settings.manualCity;
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => refresh());
  }

  final AppSettings settings;
  WeatherData? data;
  WeatherStatus status = WeatherStatus.idle;
  Timer? _timer;
  bool _busy = false;
  late bool _lastUnitF;
  String? _lastCity;

  void _onSettings() {
    if (settings.fahrenheit != _lastUnitF || settings.manualCity != _lastCity) {
      _lastUnitF = settings.fahrenheit;
      _lastCity = settings.manualCity;
      refresh(force: true);
    }
  }

  /// Refreshes if data is older than 15 minutes (or [force]).
  Future<void> refresh({bool force = false}) async {
    if (_busy) return;
    final d = data;
    if (!force && d != null && DateTime.now().difference(d.fetchedAt) < const Duration(minutes: 14) &&
        d.fahrenheit == settings.fahrenheit) {
      return;
    }
    _busy = true;
    if (data == null) {
      status = WeatherStatus.loading;
      notifyListeners();
    }
    try {
      double lat, lon;
      String city;
      if (settings.manualCity != null && settings.manualLat != null) {
        lat = settings.manualLat!;
        lon = settings.manualLon!;
        city = settings.manualCity!;
      } else {
        // Never prompt from here: no permission request and no "turn on location" dialog.
        // Prompting on every refresh/resume made Android ask again and again.
        final perm = await Geolocator.checkPermission();
        final granted = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
        Position? pos;
        if (granted) {
          try {
            pos = await Geolocator.getLastKnownPosition();
          } catch (_) {}
          final serviceOn = await Geolocator.isLocationServiceEnabled().catchError((_) => false);
          if (serviceOn) {
            try {
              pos = await Geolocator.getCurrentPosition(
                // LocationManager never shows the Play Services "enable location" resolution dialog.
                locationSettings: AndroidSettings(
                  accuracy: LocationAccuracy.low,
                  forceLocationManager: true,
                  timeLimit: const Duration(seconds: 12),
                ),
              );
            } catch (_) {}
          }
        }
        final saved = _savedLocation();
        if (pos != null) {
          lat = pos.latitude;
          lon = pos.longitude;
          city = await _cityName(lat, lon) ?? (saved?.$3 ?? data?.city ?? '');
          _saveLocation(lat, lon, city);
        } else if (saved != null) {
          // Location is off or unavailable: use the last place we successfully located.
          (lat, lon, city) = saved;
        } else {
          if (data == null) status = granted ? WeatherStatus.error : WeatherStatus.noPermission;
          return;
        }
      }
      data = await _fetch(lat, lon, city);
      status = WeatherStatus.ready;
      settings.setString('weatherCache', jsonEncode(data!.toJson()));
    } catch (e) {
      if (data == null) status = WeatherStatus.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Last successfully resolved device location (lat, lon, city), persisted across launches.
  (double, double, String)? _savedLocation() {
    final raw = settings.getString('lastLocation');
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return ((j['lat'] as num).toDouble(), (j['lon'] as num).toDouble(), (j['city'] as String?) ?? '');
    } catch (_) {
      return null;
    }
  }

  void _saveLocation(double lat, double lon, String city) {
    settings.setString('lastLocation', jsonEncode({'lat': lat, 'lon': lon, 'city': city}));
  }

  Future<String?> _cityName(double lat, double lon) async {
    try {
      final marks = await geo.Geocoding().placemarkFromCoordinates(lat, lon, locale: Locale(settings.lang.name));
      if (marks.isEmpty) return null;
      final m = marks.first;
      for (final s in [m.locality, m.subAdministrativeArea, m.administrativeArea, m.country]) {
        if (s != null && s.trim().isNotEmpty) return s.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<WeatherData> _fetch(double lat, double lon, String city) async {
    final f = settings.fahrenheit;
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': 'temperature_2m,weather_code,is_day',
      'hourly': 'temperature_2m,weather_code,is_day',
      'daily': 'temperature_2m_max,temperature_2m_min',
      'forecast_days': '2',
      'timezone': 'auto',
      if (f) 'temperature_unit': 'fahrenheit',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final daily = j['daily'] as Map<String, dynamic>;
    final hourly = j['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).cast<String>();
    final temps = (hourly['temperature_2m'] as List);
    final codes = (hourly['weather_code'] as List);
    final days = (hourly['is_day'] as List);
    final now = DateTime.now();
    final hours = <HourForecast>[];
    for (var i = 0; i < times.length; i++) {
      final t = DateTime.parse(times[i]);
      if (t.isAfter(now.subtract(const Duration(minutes: 59))) && hours.length < 24) {
        if (temps[i] == null) continue;
        hours.add(HourForecast(t, (temps[i] as num).toDouble(), (codes[i] as num?)?.toInt() ?? 0, days[i] == 1));
      }
    }
    return WeatherData(
      city: city,
      temp: (cur['temperature_2m'] as num).toDouble(),
      code: (cur['weather_code'] as num).toInt(),
      isDay: cur['is_day'] == 1,
      high: ((daily['temperature_2m_max'] as List).first as num).toDouble(),
      low: ((daily['temperature_2m_min'] as List).first as num).toDouble(),
      hours: hours,
      fetchedAt: DateTime.now(),
      fahrenheit: f,
    );
  }

  /// Search city via Open-Meteo geocoding. Returns (name, lat, lon) or null.
  static Future<(String, double, double)?> searchCity(String q, String lang) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {'name': q, 'count': '1', 'language': lang});
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final r = (j['results'] as List?)?.firstOrNull as Map<String, dynamic>?;
      if (r == null) return null;
      return (r['name'] as String, (r['latitude'] as num).toDouble(), (r['longitude'] as num).toDouble());
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    settings.removeListener(_onSettings);
    super.dispose();
  }
}
