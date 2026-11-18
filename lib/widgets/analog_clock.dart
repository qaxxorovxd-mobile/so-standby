import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/clock.dart';

enum AnalogFace {
  /// Dark disc with 1–12 numerals and minute ticks (StandBy "Analog").
  numerals,

  /// Black face with long hour ticks and 12/3/6/9 numerals (StandBy calendar pairing).
  minimal,
}

/// iOS StandBy-style analog clock. Second hand sweeps smoothly when [smooth] is true.
class AnalogClock extends StatefulWidget {
  const AnalogClock({
    super.key,
    this.face = AnalogFace.numerals,
    required this.secondColor,
    this.smooth = true,
    this.showSeconds = true,
    this.utcOffset,
    this.light = false,
  });

  final AnalogFace face;
  final Color secondColor;
  final bool smooth;
  final bool showSeconds;

  /// When set, shows the time for this UTC offset instead of local time.
  final Duration? utcOffset;

  /// White daytime face (iOS World Clock style).
  final bool light;

  @override
  State<AnalogClock> createState() => _AnalogClockState();
}

class _AnalogClockState extends State<AnalogClock> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _now = ValueNotifier<DateTime>(DateTime.now());

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _now.value = _time());
    _sync();
    Clock.instance.addListener(_onSecond);
  }

  @override
  void didUpdateWidget(covariant AnalogClock old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final want = widget.smooth && widget.showSeconds;
    if (want && !_ticker.isActive) _ticker.start();
    if (!want && _ticker.isActive) _ticker.stop();
  }

  DateTime _time() {
    final o = widget.utcOffset;
    if (o == null) return DateTime.now();
    final u = DateTime.now().toUtc().add(o);
    return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second, u.millisecond);
  }

  void _onSecond() {
    if (!_ticker.isActive) _now.value = _time();
  }

  @override
  void dispose() {
    Clock.instance.removeListener(_onSecond);
    _ticker.dispose();
    _now.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ClockPainter(_now, widget.face, widget.secondColor, widget.showSeconds, widget.light),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.now, this.face, this.secondColor, this.showSeconds, this.light) : super(repaint: now);

  final ValueNotifier<DateTime> now;
  final AnalogFace face;
  final Color secondColor;
  final bool showSeconds;
  final bool light;

  Color get _white => light ? const Color(0xFF000000) : const Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final t = now.value;

    if (face == AnalogFace.numerals) {
      _numeralsFace(canvas, c, r);
    } else {
      _minimalFace(canvas, c, r);
    }

    final sec = t.second + t.millisecond / 1000.0;
    final min = t.minute + sec / 60.0;
    final hour = (t.hour % 12) + min / 60.0;

    // Hour hand
    _hand(canvas, c, r, hour / 12, length: 0.50, width: r * 0.068, stem: r * 0.025, stemLen: 0.11);
    // Minute hand
    _hand(canvas, c, r, min / 60, length: 0.80, width: r * 0.068, stem: r * 0.025, stemLen: 0.11);
    // Center cap
    canvas.drawCircle(c, r * 0.045, Paint()..color = _white);

    if (showSeconds) {
      final a = sec / 60 * 2 * math.pi - math.pi / 2;
      final p = Paint()
        ..color = secondColor
        ..strokeWidth = r * 0.016
        ..strokeCap = StrokeCap.round;
      final tip = c + Offset(math.cos(a), math.sin(a)) * r * 0.86;
      final tail = c - Offset(math.cos(a), math.sin(a)) * r * 0.16;
      canvas.drawLine(tail, tip, p);
      canvas.drawCircle(c, r * 0.032, Paint()..color = secondColor);
      canvas.drawCircle(c, r * 0.013, Paint()..color = light ? const Color(0xFFFFFFFF) : const Color(0xFF000000));
    }
  }

  void _hand(Canvas canvas, Offset c, double r, double turn,
      {required double length, required double width, required double stem, required double stemLen}) {
    final a = turn * 2 * math.pi - math.pi / 2;
    final dir = Offset(math.cos(a), math.sin(a));
    // thin stem from center
    canvas.drawLine(
      c,
      c + dir * r * stemLen,
      Paint()
        ..color = _white
        ..strokeWidth = stem
        ..strokeCap = StrokeCap.round,
    );
    // thick body with subtle shadow for depth
    final from = c + dir * r * stemLen;
    final to = c + dir * r * length;
    canvas.drawLine(
      from + const Offset(0, 1.5),
      to + const Offset(0, 1.5),
      Paint()
        ..color = const Color(0x66000000)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = _white
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _numeralsFace(Canvas canvas, Offset c, double r) {
    // Disc with soft gradient — like the StandBy analog widget.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: light ? const [Color(0xFFFFFFFF), Color(0xFFE5E5EA)] : const [Color(0xFF1E1E21), Color(0xFF141416)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // minute ticks
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final major = i % 5 == 0;
      final p = Paint()
        ..color = major ? _white : (light ? const Color(0xFFAEAEB2) : const Color(0xFF6E6E73))
        ..strokeWidth = major ? r * 0.018 : r * 0.010
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c + dir * r * 0.92, c + dir * r * (major ? 0.83 : 0.87), p);
    }
    for (var n = 1; n <= 12; n++) {
      final a = n / 12 * 2 * math.pi - math.pi / 2;
      final pos = c + Offset(math.cos(a), math.sin(a)) * r * 0.69;
      _text(canvas, '$n', pos, r * 0.155, FontWeight.w600, _white);
    }
  }

  void _minimalFace(Canvas canvas, Offset c, double r) {
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF000000));
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final hourMark = i % 5 == 0;
      final quarter = i % 15 == 0;
      if (quarter) continue; // numerals there
      if (hourMark) {
        canvas.drawLine(
          c + dir * r * 0.97,
          c + dir * r * 0.78,
          Paint()
            ..color = _white
            ..strokeWidth = r * 0.028
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawLine(
          c + dir * r * 0.97,
          c + dir * r * 0.92,
          Paint()
            ..color = const Color(0xFF48484A)
            ..strokeWidth = r * 0.012
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (final n in [12, 3, 6, 9]) {
      final a = n / 12 * 2 * math.pi - math.pi / 2;
      final pos = c + Offset(math.cos(a), math.sin(a)) * r * 0.80;
      _text(canvas, '$n', pos, r * 0.24, FontWeight.w600, _white);
    }
  }

  void _text(Canvas canvas, String s, Offset center, double size, FontWeight w, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size,
          fontWeight: w,
          color: color,
          height: 1,
          letterSpacing: -size * 0.03,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.face != face || old.secondColor != secondColor || old.showSeconds != showSeconds || old.light != light;
}
