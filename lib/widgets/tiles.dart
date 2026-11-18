import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:geolocator/geolocator.dart';

import '../core/clock.dart';
import '../core/l10n.dart';
import '../core/services_scope.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../services/weather.dart';

/// Scales its (naturally sized) child to fill the available box, keeping aspect ratio.
class Fit extends StatelessWidget {
  const Fit({super.key, required this.child, this.alignment = Alignment.center});
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => FittedBox(fit: BoxFit.contain, alignment: alignment, child: child);
}

String deg(double v) => '${v.round()}°';

// ───────────────────────────── Weather ─────────────────────────────

class WeatherTile extends StatelessWidget {
  const WeatherTile({super.key, this.compactHours = false});
  final bool compactHours;

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context).weather;
    final s = SettingsScope.of(context);
    final t = s.t;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final d = svc.data;
        if (d == null) {
          return _WeatherPlaceholder(status: svc.status);
        }
        return Fit(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(d.city.isEmpty ? t.weather : d.city,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: sf(26, weight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  if (s.manualCity == null)
                    Transform.rotate(
                      angle: 0.785,
                      child: const Icon(CupertinoIcons.location_north_fill, size: 16, color: Palette.label),
                    ),
                ],
              ),
              Text(deg(d.temp), style: sf(112, weight: FontWeight.w600, height: 1.05)),
              const SizedBox(height: 6),
              Icon(weatherIcon(d.code, isDay: d.isDay), size: 30, color: weatherIconColor(d.code, isDay: d.isDay)),
              const SizedBox(height: 6),
              Text(t.weatherText(d.code), style: sf(24, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${t.high}:${deg(d.high)}  ${t.low}:${deg(d.low)}', style: sf(24, weight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

class _WeatherPlaceholder extends StatelessWidget {
  const _WeatherPlaceholder({required this.status});
  final WeatherStatus status;

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final svc = Services.of(context).weather;
    if (status == WeatherStatus.loading || status == WeatherStatus.idle) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CupertinoActivityIndicator(radius: 14, color: Palette.secondary),
          const SizedBox(height: 14),
          Text(t.loadingWeather, style: sf(17, weight: FontWeight.w500, color: Palette.secondary)),
        ]),
      );
    }
    final noPerm = status == WeatherStatus.noPermission;
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (noPerm) {
            final p = await Geolocator.requestPermission();
            if (p == LocationPermission.deniedForever) await Geolocator.openAppSettings();
          }
          svc.refresh(force: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(noPerm ? CupertinoIcons.location_fill : CupertinoIcons.cloud_fill, size: 44, color: Palette.secondary),
            const SizedBox(height: 14),
            Text(noPerm ? t.tapToEnableLocation : t.offline,
                textAlign: TextAlign.center, style: sf(18, weight: FontWeight.w600, color: Palette.secondary)),
            const SizedBox(height: 10),
            Text(noPerm ? t.allow : t.refresh, style: sf(17, weight: FontWeight.w700, color: Palette.blue)),
          ]),
        ),
      ),
    );
  }
}

/// Inline "☁ 11°  Toshkent" summary used on smart and clock pages.
class WeatherInline extends StatelessWidget {
  const WeatherInline({super.key, this.size = 22, this.color = Palette.label, this.showCity = true});
  final double size;
  final Color color;
  final bool showCity;

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context).weather;
    final t = SettingsScope.of(context).t;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final d = svc.data;
        if (d == null) return const SizedBox.shrink();
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(weatherIcon(d.code, isDay: d.isDay), size: size * 1.1, color: weatherIconColor(d.code, isDay: d.isDay)),
          SizedBox(width: size * 0.4),
          Text(deg(d.temp), style: sf(size, weight: FontWeight.w700, color: color)),
          SizedBox(width: size * 0.5),
          Text(
            showCity && d.city.isNotEmpty ? '${t.weatherText(d.code)} · ${d.city}' : t.weatherText(d.code),
            style: sf(size, weight: FontWeight.w600, color: color.withValues(alpha: 0.6)),
          ),
        ]);
      },
    );
  }
}

class HourlyRow extends StatelessWidget {
  const HourlyRow({super.key, this.count = 6});
  final int count;

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context).weather;
    final s = SettingsScope.of(context);
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final d = svc.data;
        if (d == null || d.hours.isEmpty) return const SizedBox.shrink();
        final hours = d.hours.take(count).toList();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < hours.length; i++)
              SizedBox(
                width: 76,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    i == 0 ? s.t.now : (s.use24h ? two(hours[i].time.hour) : formatHour(hours[i].time, false)),
                    style: sf(17, weight: FontWeight.w600, color: Palette.secondary),
                  ),
                  const SizedBox(height: 10),
                  Icon(weatherIcon(hours[i].code, isDay: hours[i].isDay),
                      size: 26, color: weatherIconColor(hours[i].code, isDay: hours[i].isDay)),
                  const SizedBox(height: 10),
                  Text(deg(hours[i].temp), style: sf(20, weight: FontWeight.w700)),
                ]),
              ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────── Date ─────────────────────────────

class DateTile extends StatelessWidget {
  const DateTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return ClockBuilder(builder: (context, now) {
      return Fit(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(s.lang == AppLang.en ? s.t.weekdayShort(now.weekday) : s.t.weekday(now.weekday),
                  style: sf(40, weight: FontWeight.w700, color: Palette.red)),
              const SizedBox(width: 12),
              Text(s.t.month(now.month), style: sf(40, weight: FontWeight.w700, color: s.accent.withValues(alpha: 0.72))),
            ]),
            Text('${now.day}', style: sf(200, weight: FontWeight.w600, color: s.accent, height: 1.0, tabular: true)),
          ],
        ),
      );
    });
  }
}

// ───────────────────────────── Calendar ─────────────────────────────

class CalendarTile extends StatelessWidget {
  const CalendarTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final t = s.t;
    return ClockBuilder(builder: (context, now) {
      final first = DateTime(now.year, now.month, 1);
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      final lead = first.weekday - 1; // Monday-first
      final cells = <int?>[...List.filled(lead, null), for (var d = 1; d <= daysInMonth; d++) d];
      while (cells.length % 7 != 0) {
        cells.add(null);
      }
      const cell = 44.0;
      return Fit(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 10, bottom: 6),
              child: Text(t.month(now.month).toUpperCase(), style: sf(19, weight: FontWeight.w700, color: Palette.red, tracking: 0.3)),
            ),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 1; i <= 7; i++)
                SizedBox(
                  width: cell,
                  height: 34,
                  child: Center(
                    child: Text(t.weekdayLetter(i),
                        style: sf(16, weight: FontWeight.w700, color: i >= 6 ? Palette.secondary : Palette.label)),
                  ),
                ),
            ]),
            for (var r = 0; r < cells.length ~/ 7; r++)
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var c = 0; c < 7; c++)
                  SizedBox(
                    width: cell,
                    height: cell - 4,
                    child: Center(child: _day(cells[r * 7 + c], c >= 5, now.day)),
                  ),
              ]),
          ],
        ),
      );
    });
  }

  Widget _day(int? d, bool weekend, int today) {
    if (d == null) return const SizedBox.shrink();
    final isToday = d == today;
    final text = Text('$d',
        style: sf(18, weight: FontWeight.w700, color: isToday ? Palette.label : (weekend ? Palette.secondary : Palette.label)));
    if (!isToday) return text;
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Palette.red, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: text,
    );
  }
}

// ───────────────────────────── Digital ─────────────────────────────

class DigitalTime extends StatelessWidget {
  const DigitalTime({super.key, this.color, this.size = 200, this.weight = FontWeight.w700, this.seconds});
  final Color? color;
  final double size;
  final FontWeight weight;
  final bool? seconds;

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return ClockBuilder(builder: (context, now) {
      final showSec = seconds ?? s.showSeconds;
      return Text.rich(
        TextSpan(children: [
          TextSpan(text: formatTime(now, s.use24h)),
          if (showSec)
            TextSpan(text: ':${two(now.second)}', style: TextStyle(color: (color ?? s.accent).withValues(alpha: 0.55))),
        ]),
        maxLines: 1,
        style: sf(size, weight: weight, color: color ?? s.accent, height: 1.0, tabular: true),
      );
    });
  }
}

class BatteryPill extends StatelessWidget {
  const BatteryPill({super.key});

  @override
  Widget build(BuildContext context) {
    final b = Services.of(context).battery;
    return ListenableBuilder(
      listenable: b,
      builder: (context, _) {
        if (b.level < 0) return const SizedBox.shrink();
        final color = b.charging ? Palette.green : (b.level <= 20 ? Palette.red : Palette.secondary);
        return Row(mainAxisSize: MainAxisSize.min, children: [
          if (b.charging) Icon(CupertinoIcons.bolt_fill, size: 16, color: color),
          const SizedBox(width: 4),
          Text('${b.level}%', style: sf(16, weight: FontWeight.w700, color: color)),
        ]);
      },
    );
  }
}
