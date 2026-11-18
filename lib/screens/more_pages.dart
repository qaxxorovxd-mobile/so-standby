import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../core/clock.dart';
import '../core/services_scope.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../services/weather.dart';
import '../widgets/analog_clock.dart';
import '../widgets/tiles.dart';
import 'pages.dart';

// ───────────────────────── Digital + date tile ─────────────────────────

class DigitalDateTile extends StatelessWidget {
  const DigitalDateTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return ClockBuilder(
      builder: (context, now) => Fit(
        alignment: Alignment.centerLeft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(s.t.weekday(now.weekday), style: sf(34, weight: FontWeight.w700, color: Palette.red)),
          Text('${s.t.month(now.month)} ${now.day}', style: sf(34, weight: FontWeight.w700, color: Palette.secondary)),
          DigitalTime(size: 150, weight: FontWeight.w800, color: Palette.label, seconds: false),
        ]),
      ),
    );
  }
}

// ───────────────────────── World clock ─────────────────────────

/// Second Sunday of March .. first Sunday of November (US).
bool _usDst(DateTime utc) {
  final y = utc.year;
  DateTime nthSunday(int month, int n) {
    var d = DateTime.utc(y, month, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * (n - 1)));
  }

  final start = nthSunday(3, 2).add(const Duration(hours: 7)); // 2:00 local EST
  final end = nthSunday(11, 1).add(const Duration(hours: 6)); // 2:00 local EDT
  return utc.isAfter(start) && utc.isBefore(end);
}

/// Last Sunday of March 01:00 UTC .. last Sunday of October 01:00 UTC (EU).
bool _euDst(DateTime utc) {
  DateTime lastSunday(int month) {
    var d = DateTime.utc(utc.year, month + 1, 1).subtract(const Duration(days: 1));
    while (d.weekday != DateTime.sunday) {
      d = d.subtract(const Duration(days: 1));
    }
    return d.add(const Duration(hours: 1));
  }

  return utc.isAfter(lastSunday(3)) && utc.isBefore(lastSunday(10));
}

class _City {
  const _City(this.name, this.offset);
  final String name;
  final Duration Function(DateTime utc) offset;
}

final _cities = <_City>[
  _City('Cupertino', (u) => Duration(hours: _usDst(u) ? -7 : -8)),
  _City('New York', (u) => Duration(hours: _usDst(u) ? -4 : -5)),
  _City('London', (u) => Duration(hours: _euDst(u) ? 1 : 0)),
  _City('Dubai', (u) => const Duration(hours: 4)),
  _City('Tashkent', (u) => const Duration(hours: 5)),
  _City('Tokyo', (u) => const Duration(hours: 9)),
];

class WorldClockPage extends StatelessWidget {
  const WorldClockPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final cities = land ? [_cities[0], _cities[1], _cities[2], _cities[5]] : _cities;
      final pad = c.biggest.shortestSide * 0.07;
      return ClockBuilder(builder: (context, now) {
        final utc = now.toUtc();
        final localOffset = now.timeZoneOffset;
        Widget cell(_City city) {
          final off = city.offset(utc);
          final t = utc.add(off);
          final day = t.hour >= 6 && t.hour < 18;
          final diff = (off - localOffset).inMinutes / 60;
          final diffText = diff == 0 ? 'Today' : '${diff > 0 ? '+' : ''}${diff == diff.roundToDouble() ? diff.round() : diff}H';
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
              child: AnalogClock(
                utcOffset: off,
                light: day,
                secondColor: s.accent == Accents.white ? Accents.orange : s.accent,
                smooth: s.smoothSeconds,
              ),
            ),
            const SizedBox(height: 12),
            Text(city.name, maxLines: 1, style: sf(20, weight: FontWeight.w700)),
            Text(diffText, style: sf(15, weight: FontWeight.w600, color: Palette.secondary)),
          ]);
        }

        return Padding(
          padding: EdgeInsets.all(pad),
          child: land
              ? Row(children: [for (final ct in cities) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: cell(ct)))])
              : Column(children: [
                  for (var r = 0; r < 3; r++)
                    Expanded(
                      child: Row(children: [
                        for (var k = 0; k < 2; k++)
                          Expanded(child: Padding(padding: const EdgeInsets.all(10), child: cell(cities[r * 2 + k]))),
                      ]),
                    ),
                ]),
        );
      });
    });
  }
}

// ───────────────────────── Batteries ─────────────────────────

class BatteryTile extends StatelessWidget {
  const BatteryTile({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Services.of(context).battery;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) {
        final level = b.level < 0 ? 0 : b.level;
        final color = b.charging ? Palette.green : (level <= 20 ? Palette.red : Palette.green);
        return Center(
          child: Fit(
            child: SizedBox(
              width: 300,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: _RingsPainter([(level / 100, color)], width: 26),
                    child: Center(
                      child: Icon(
                        b.charging ? CupertinoIcons.bolt_fill : CupertinoIcons.device_phone_portrait,
                        size: 84,
                        color: Palette.label,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(b.level < 0 ? '--' : '$level%', style: sf(64, weight: FontWeight.w800, tabular: true)),
                Text(b.charging ? 'Charging' : 'Battery',
                    style: sf(22, weight: FontWeight.w600, color: b.charging ? Palette.green : Palette.secondary)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

/// Concentric Activity-style rings. Each entry: (progress 0..1, color).
class _RingsPainter extends CustomPainter {
  _RingsPainter(this.rings, {this.width = 22, this.gap = 6});
  final List<(double, Color)> rings;
  final double width;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    var r = size.shortestSide / 2 - width / 2;
    for (final (p, color) in rings) {
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = color.withValues(alpha: 0.22),
      );
      final sweep = 2 * math.pi * p.clamp(0.0, 1.0);
      if (sweep > 0.001) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..shader = SweepGradient(
              startAngle: 0,
              endAngle: 2 * math.pi,
              colors: [Color.lerp(color, const Color(0xFF000000), 0.15)!, color],
              transform: const GradientRotation(-math.pi / 2),
            ).createShader(rect),
        );
      }
      r -= width + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => true;
}

// ───────────────────────── Day progress ─────────────────────────

class DayProgressPage extends StatelessWidget {
  const DayProgressPage({super.key});

  static const _colors = [Color(0xFFFA114F), Color(0xFF92E82A), Color(0xFF1EEAEF), Color(0xFFFFD60A)];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.08;
      return ClockBuilder(builder: (context, now) {
        final dayStart = DateTime(now.year, now.month, now.day);
        final day = now.difference(dayStart).inSeconds / 86400;
        final week = (now.weekday - 1 + day) / 7;
        final dim = DateTime(now.year, now.month + 1, 0).day;
        final month = (now.day - 1 + day) / dim;
        final yStart = DateTime(now.year);
        final year = now.difference(yStart).inSeconds / DateTime(now.year + 1).difference(yStart).inSeconds;
        final values = [day, week, month, year];
        const labels = ['Day', 'Week', 'Month', 'Year'];

        final rings = AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(painter: _RingsPainter([for (var i = 0; i < 4; i++) (values[i], _colors[i])], width: 24, gap: 5)),
        );
        final legend = Fit(
          alignment: land ? Alignment.centerLeft : Alignment.center,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                  SizedBox(width: 110, child: Text(labels[i], style: sf(28, weight: FontWeight.w700))),
                  Text('${(values[i] * 100).toStringAsFixed(i == 3 ? 1 : 0)}%',
                      style: sf(40, weight: FontWeight.w800, color: _colors[i], tabular: true)),
                ]),
              ),
          ]),
        );
        return Padding(
          padding: EdgeInsets.all(pad),
          child: land
              ? Row(children: [Expanded(child: Center(child: rings)), SizedBox(width: pad), Expanded(child: legend)])
              : Column(children: [Expanded(flex: 5, child: Center(child: rings)), SizedBox(height: pad), Expanded(flex: 3, child: legend)]),
        );
      });
    });
  }
}

// ───────────────────────── Forecast ─────────────────────────

class ForecastPage extends StatelessWidget {
  const ForecastPage({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context).weather;
    final t = SettingsScope.of(context).t;
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.08;
      return ListenableBuilder(
        listenable: svc,
        builder: (context, _) {
          final d = svc.data;
          if (d == null) return const WeatherTile();
          final top = Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text(d.city.isEmpty ? t.weather : d.city, style: sf(28, weight: FontWeight.w700)),
                const SizedBox(width: 8),
                Transform.rotate(angle: 0.785, child: const Icon(CupertinoIcons.location_north_fill, size: 16, color: Palette.label)),
              ]),
              Text(deg(d.temp), style: sf(120, weight: FontWeight.w300, height: 1.05)),
            ]),
            const SizedBox(width: 60),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                Icon(weatherIcon(d.code, isDay: d.isDay), size: 40, color: weatherIconColor(d.code, isDay: d.isDay)),
                const SizedBox(height: 10),
                Text(t.weatherText(d.code), style: sf(24, weight: FontWeight.w700)),
                Text('${t.high}:${deg(d.high)}  ${t.low}:${deg(d.low)}', style: sf(24, weight: FontWeight.w700)),
              ]),
            ),
          ]);
          return Container(
            margin: EdgeInsets.all(pad * 0.6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: d.isDay ? const [Color(0xFF2B6CB8), Color(0xFF5B9BD8)] : const [Color(0xFF0B1026), Color(0xFF2A3156)],
              ),
            ),
            padding: EdgeInsets.all(pad * 0.7),
            child: Fit(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                top,
                SizedBox(height: land ? 18 : 30),
                Container(height: 1, width: 470, color: const Color(0x40FFFFFF)),
                const SizedBox(height: 18),
                const HourlyRow(count: 6),
              ]),
            ),
          );
        },
      );
    });
  }
}

// ───────────────────────── Stopwatch ─────────────────────────

class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  static final _sw = Stopwatch(); // survives page rebuilds
  static Duration _lastLap = Duration.zero;
  static final List<Duration> _laps = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (_sw.isRunning && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final cs = (d.inMilliseconds % 1000) ~/ 10;
    return '${two(m)}:${two(s)},${two(cs)}';
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() => _sw.isRunning ? _sw.stop() : _sw.start());
  }

  void _lapReset() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_sw.isRunning) {
        _laps.insert(0, _sw.elapsed - _lastLap);
        _lastLap = _sw.elapsed;
      } else {
        _sw.reset();
        _laps.clear();
        _lastLap = Duration.zero;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = _sw.isRunning;
    final started = _sw.elapsedMilliseconds > 0;
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.08;
      final time = Fit(child: Text(_fmt(_sw.elapsed), style: sf(160, weight: FontWeight.w300, tabular: true, height: 1)));
      final buttons = Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _CircleBtn(
          label: running || !started ? 'Lap' : 'Reset',
          fg: Palette.label,
          bg: const Color(0xFF333336),
          enabled: started,
          onTap: _lapReset,
        ),
        _CircleBtn(
          label: running ? 'Stop' : 'Start',
          fg: running ? const Color(0xFFFF453A) : const Color(0xFF30D158),
          bg: running ? const Color(0xFF330E0C) : const Color(0xFF0A2A12),
          onTap: _toggle,
        ),
      ]);
      final laps = _laps.isEmpty
          ? const SizedBox.shrink()
          : Column(children: [
              for (var i = 0; i < math.min(_laps.length, land ? 2 : 4); i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.separator, width: 0.5))),
                  child: Row(children: [
                    Text('Lap ${_laps.length - i}', style: sf(17, weight: FontWeight.w600)),
                    const Spacer(),
                    Text(_fmt(_laps[i]), style: sf(17, weight: FontWeight.w600, tabular: true)),
                  ]),
                ),
            ]);
      return Padding(
        padding: EdgeInsets.all(pad),
        child: land
            ? Row(children: [
                Expanded(flex: 3, child: Center(child: time)),
                SizedBox(width: pad),
                Expanded(
                  flex: 2,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [buttons, const SizedBox(height: 16), laps]),
                ),
              ])
            : Column(children: [
                Expanded(child: Center(child: time)),
                buttons,
                const SizedBox(height: 20),
                SizedBox(height: 180, child: SingleChildScrollView(child: laps)),
              ]),
      );
    });
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.label, required this.fg, required this.bg, required this.onTap, this.enabled = true});
  final String label;
  final Color fg, bg;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: bg, width: 2.5)),
            child: Container(
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(label, style: sf(18, weight: FontWeight.w600, color: fg)),
            ),
          ),
        ),
      );
}
