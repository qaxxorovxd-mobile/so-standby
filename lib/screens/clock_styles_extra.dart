import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/clock.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../widgets/tiles.dart';
import 'pages.dart';

String _hh(DateTime now, bool use24h) => use24h ? two(now.hour) : formatHour(now, false).padLeft(2, '0');

// ───────────────────────── Solar ─────────────────────────

/// Sky gradient that follows the time of day, with the sun/moon travelling an arc.
class SolarStyle extends StatelessWidget {
  const SolarStyle({super.key});

  static List<Color> _sky(double h) {
    if (h < 5 || h >= 21) return const [Color(0xFF02040C), Color(0xFF0B1433)];
    if (h < 7) return const [Color(0xFF1D2B64), Color(0xFFF8A170)];
    if (h < 10) return const [Color(0xFF3A7BD5), Color(0xFFFFD3A5)];
    if (h < 16) return const [Color(0xFF1C6DD0), Color(0xFF8EC5FC)];
    if (h < 19) return const [Color(0xFF3B4371), Color(0xFFF3904F)];
    return const [Color(0xFF141E30), Color(0xFF6B3A6B)];
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return ClockBuilder(builder: (context, now) {
      final h = now.hour + now.minute / 60;
      final day = h >= 6 && h < 18;
      // 0..1 progress across the arc (day: 6→18, night: 18→6)
      final p = day ? (h - 6) / 12 : ((h + 6) % 24) / 12;
      return LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth, ht = c.maxHeight;
        final cx = w * (0.1 + 0.8 * p);
        final cy = ht * 0.62 - math.sin(p * math.pi) * ht * 0.45;
        final orb = c.biggest.shortestSide * 0.22;
        return AnimatedContainer(
          duration: const Duration(seconds: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _sky(h)),
          ),
          child: Stack(children: [
            Positioned(
              left: cx - orb * 1.5,
              top: cy - orb * 1.5,
              child: Container(
                width: orb * 3,
                height: orb * 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    (day ? const Color(0xFFFFE9A8) : const Color(0xFFE5E5EA)).withValues(alpha: day ? 0.75 : 0.35),
                    const Color(0x00FFFFFF),
                  ]),
                ),
              ),
            ),
            Positioned(
              left: cx - orb / 2,
              top: cy - orb / 2,
              child: Container(
                width: orb,
                height: orb,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: day ? const Color(0xFFFFF4D6) : const Color(0xFFF2F2F7),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.all(c.biggest.shortestSide * 0.08),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: SizedBox(
                    height: ht * 0.42,
                    child: Fit(
                      alignment: Alignment.bottomLeft,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(s.t.longDate(now), style: sf(26, weight: FontWeight.w700, color: const Color(0xDDFFFFFF))),
                        Text(formatTime(now, s.use24h),
                            style: sf(170, weight: FontWeight.w700, height: 1.0, tabular: true)
                                .copyWith(shadows: const [Shadow(color: Color(0x40000000), blurRadius: 30)])),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        );
      });
    });
  }
}

// ───────────────────────── Float ─────────────────────────

/// Huge overlapping digits in two tones, like StandBy "Float".
class FloatStyle extends StatelessWidget {
  const FloatStyle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final a = s.accent == Accents.white ? Accents.cyan : s.accent;
    final b = Color.lerp(a, const Color(0xFFFFFFFF), 0.65)!;
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      return ClockBuilder(builder: (context, now) {
        final st = sf(300, weight: FontWeight.w900, height: 0.82, tracking: -30, tabular: true);
        final hours = Text(_hh(now, s.use24h), style: st.copyWith(color: b));
        final mins = Text(two(now.minute), style: st.copyWith(color: a.withValues(alpha: 0.92)));
        return Padding(
          padding: EdgeInsets.all(c.biggest.shortestSide * 0.05),
          child: Fit(
            child: land
                ? SizedBox(
                    width: 640,
                    height: 330,
                    child: Stack(children: [
                      Positioned(left: 0, top: 0, child: hours),
                      Positioned(left: 290, top: 84, child: mins),
                    ]),
                  )
                : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    hours,
                    Transform.translate(offset: const Offset(70, -30), child: mins),
                  ]),
          ),
        );
      });
    });
  }
}

// ───────────────────────── Outline ─────────────────────────

class OutlineStyle extends StatelessWidget {
  const OutlineStyle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      return ClockBuilder(builder: (context, now) {
        // Duotone: hours as a translucent tint, minutes solid.
        final stroke = sf(240, weight: FontWeight.w900, height: 1.0, tabular: true, color: s.accent.withValues(alpha: 0.28));
        final fillMin = sf(240, weight: FontWeight.w900, height: 1.0, tabular: true, color: s.accent);
        final colonOn = now.second.isEven;
        return Padding(
          padding: EdgeInsets.all(c.biggest.shortestSide * 0.07),
          child: Center(
            child: Fit(
              child: land
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_hh(now, s.use24h), style: stroke),
                      AnimatedOpacity(
                        opacity: colonOn ? 1 : 0.25,
                        duration: const Duration(milliseconds: 300),
                        child: Text(':', style: fillMin),
                      ),
                      Text(two(now.minute), style: fillMin),
                    ])
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_hh(now, s.use24h), style: stroke),
                      Text(two(now.minute), style: fillMin),
                    ]),
            ),
          ),
        );
      });
    });
  }
}

// ───────────────────────── Word clock ─────────────────────────

class WordsStyle extends StatelessWidget {
  const WordsStyle({super.key});

  static const _nums = ['twelve', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven'];

  static (String, String) phrase(DateTime d) {
    final m5 = ((d.minute + 2.5) ~/ 5) * 5 % 60;
    var h = d.hour % 12;
    final roll = (d.minute + 2.5) >= 57.5 || m5 > 30;
    if (roll) h = (h + 1) % 12;
    final hourWord = _nums[h];
    final mid = switch (m5) {
      0 => "o'clock",
      5 => 'five past',
      10 => 'ten past',
      15 => 'quarter past',
      20 => 'twenty past',
      25 => 'twenty‑five past',
      30 => 'half past',
      35 => 'twenty‑five to',
      40 => 'twenty to',
      45 => 'quarter to',
      50 => 'ten to',
      _ => 'five to',
    };
    return (mid, hourWord);
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      return ClockBuilder(builder: (context, now) {
        final (mid, hour) = phrase(now);
        final lines = mid == "o'clock" ? [hour, mid] : [mid, hour];
        return Padding(
          padding: EdgeInsets.all(c.biggest.shortestSide * 0.08),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Fit(
              alignment: Alignment.centerLeft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text("It's", style: sf(64, weight: FontWeight.w800, color: Palette.tertiary, height: 1.05)),
                Text(lines[0], style: sf(96, weight: FontWeight.w900, height: 1.02)),
                Text(lines[1], style: sf(96, weight: FontWeight.w900, color: s.accent, height: 1.02)),
                const SizedBox(height: 14),
                Text(formatTime(now, s.use24h), style: sf(30, weight: FontWeight.w700, color: Palette.secondary, tabular: true)),
              ]),
            ),
          ),
        );
      });
    });
  }
}

// ───────────────────────── Dot matrix ─────────────────────────

class DotMatrixStyle extends StatelessWidget {
  const DotMatrixStyle({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      return ClockBuilder(builder: (context, now) {
        final text = land ? '${_hh(now, s.use24h)}:${two(now.minute)}' : '${_hh(now, s.use24h)}\n${two(now.minute)}';
        final dots = _DotText(text: text, on: s.accent, blinkColon: now.second.isOdd);
        return Padding(
          padding: EdgeInsets.all(c.biggest.shortestSide * 0.08),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: dots),
              const SizedBox(height: 18),
              Text(s.t.longDate(now).toUpperCase(),
                  style: sf(16, weight: FontWeight.w800, color: s.accent.withValues(alpha: 0.6), tracking: 3)),
            ]),
          ),
        );
      });
    });
  }
}

class _DotText extends StatelessWidget {
  const _DotText({required this.text, required this.on, required this.blinkColon});
  final String text;
  final Color on;
  final bool blinkColon;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final cols = lines.map(_DotPainter.widthOf).reduce(math.max);
    final rows = lines.length * 7 + (lines.length - 1) * 2;
    return AspectRatio(
      aspectRatio: cols / rows,
      child: CustomPaint(painter: _DotPainter(lines, cols, rows, on, blinkColon)),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.lines, this.cols, this.rows, this.on, this.blinkColon);
  final List<String> lines;
  final int cols, rows;
  final Color on;
  final bool blinkColon;

  static const _glyphs = <String, List<String>>{
    '0': ['01110', '10001', '10011', '10101', '11001', '10001', '01110'],
    '1': ['00100', '01100', '00100', '00100', '00100', '00100', '01110'],
    '2': ['01110', '10001', '00001', '00010', '00100', '01000', '11111'],
    '3': ['11111', '00010', '00100', '00010', '00001', '10001', '01110'],
    '4': ['00010', '00110', '01010', '10010', '11111', '00010', '00010'],
    '5': ['11111', '10000', '11110', '00001', '00001', '10001', '01110'],
    '6': ['00110', '01000', '10000', '11110', '10001', '10001', '01110'],
    '7': ['11111', '00001', '00010', '00100', '01000', '01000', '01000'],
    '8': ['01110', '10001', '10001', '01110', '10001', '10001', '01110'],
    '9': ['01110', '10001', '10001', '01111', '00001', '00010', '01100'],
    ':': ['0', '0', '1', '0', '1', '0', '0'],
  };

  static int widthOf(String line) {
    var w = 0;
    for (var i = 0; i < line.length; i++) {
      w += _glyphs[line[i]]![0].length + (i < line.length - 1 ? 1 : 0);
    }
    return w;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cols;
    final r = cell * 0.40;
    final offPaint = Paint()..color = on.withValues(alpha: 0.10);
    final onPaint = Paint()..color = on;
    final glow = Paint()
      ..color = on.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.5);
    var y0 = 0;
    for (final line in lines) {
      final lw = widthOf(line);
      var x0 = (cols - lw) ~/ 2;
      for (var i = 0; i < line.length; i++) {
        final ch = line[i];
        final g = _glyphs[ch]!;
        for (var y = 0; y < 7; y++) {
          for (var x = 0; x < g[y].length; x++) {
            var lit = g[y][x] == '1';
            if (ch == ':' && blinkColon) lit = false;
            final c = Offset((x0 + x + 0.5) * cell, (y0 + y + 0.5) * cell);
            if (lit) {
              canvas.drawCircle(c, r * 1.3, glow);
              canvas.drawCircle(c, r, onPaint);
            } else {
              canvas.drawCircle(c, r, offPaint);
            }
          }
        }
        x0 += g[0].length + 1;
      }
      y0 += 9;
    }
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) =>
      old.lines.join() != lines.join() || old.on != on || old.blinkColon != blinkColon;
}
