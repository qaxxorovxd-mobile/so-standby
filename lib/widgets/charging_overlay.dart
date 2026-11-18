import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../core/style.dart';
import '../services/power.dart';

/// Full-screen charging animation.
///
/// * Wired: an energy stream with particles flies in from the edge where the USB‑C
///   port is, plugs into the battery ring and fills it.
/// * Wireless: a MagSafe-style shimmering ring blooms from the center, then
///   settles into the battery ring.
///
/// Ends with ripples and a soft fade, then calls [onDone].
class ChargingOverlay extends StatefulWidget {
  const ChargingOverlay({super.key, required this.event, required this.onDone});
  final ChargeEvent event;
  final VoidCallback onDone;

  @override
  State<ChargingOverlay> createState() => _ChargingOverlayState();
}

class _ChargingOverlayState extends State<ChargingOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _hit = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))
      ..addListener(_haptics)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
    HapticFeedback.heavyImpact();
  }

  void _haptics() {
    if (!_hit && _c.value > 0.40) {
      _hit = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    final color = e.level <= 20 ? const Color(0xFFFFD60A) : Palette.green;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final fadeOut = 1 - _iv(t, 0.86, 1.0, Curves.easeIn);
        final bolt = _iv(t, 0.36, 0.66, Curves.elasticOut);
        final text = _iv(t, 0.42, 0.62, Curves.easeOut);
        final count = _iv(t, 0.40, 0.80, Curves.easeOutCubic);
        return IgnorePointer(
          child: Opacity(
            opacity: fadeOut,
            child: LayoutBuilder(builder: (context, c) {
              final size = c.biggest;
              final r = size.shortestSide * 0.22;
              return Stack(children: [
                Positioned.fill(
                  child: CustomPaint(painter: _EnergyPainter(t: t, event: e, color: color, ringRadius: r)),
                ),
                Center(
                  child: Transform.scale(
                    scale: 0.2 + 0.8 * bolt,
                    child: Opacity(
                      opacity: bolt.clamp(0.0, 1.0),
                      child: Icon(CupertinoIcons.bolt_fill, size: r * 0.9, color: Palette.label, shadows: [
                        Shadow(color: color.withValues(alpha: 0.9), blurRadius: 30),
                      ]),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: size.height / 2 + r + r * 0.28,
                  child: Opacity(
                    opacity: text,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - text)),
                      child: Column(children: [
                        Text('${(e.level * count).round()}%',
                            textAlign: TextAlign.center,
                            style: sf(r * 0.42, weight: FontWeight.w800, tabular: true, height: 1)),
                        SizedBox(height: r * 0.06),
                        Text(e.kind == ChargeKind.wireless ? 'Wireless Charging' : 'Charging',
                            textAlign: TextAlign.center,
                            style: sf(r * 0.15, weight: FontWeight.w700, color: color)),
                      ]),
                    ),
                  ),
                ),
              ]);
            }),
          ),
        );
      },
    );
  }
}

class _EnergyPainter extends CustomPainter {
  _EnergyPainter({required this.t, required this.event, required this.color, required this.ringRadius});
  final double t;
  final ChargeEvent event;
  final Color color;
  final double ringRadius;

  static double _iv(double t, double a, double b, [Curve curve = Curves.linear]) =>
      curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = ringRadius;

    // Dim backdrop so the page underneath recedes.
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF000000));

    if (event.kind == ChargeKind.wired) {
      _wired(canvas, size, c, r);
    } else {
      _wireless(canvas, size, c, r);
    }
    _ring(canvas, c, r);
    _ripples(canvas, c, r);
  }

  Offset _port(Size s) => switch (event.side) {
        PortSide.bottom => Offset(s.width / 2, s.height + 4),
        PortSide.top => Offset(s.width / 2, -4),
        PortSide.left => Offset(-4, s.height / 2),
        PortSide.right => Offset(s.width + 4, s.height / 2),
      };

  void _wired(Canvas canvas, Size size, Offset c, double r) {
    final p = _port(size);
    final dir = (c - p) / (c - p).distance;
    final normal = Offset(-dir.dy, dir.dx);
    final target = c - dir * r; // ring edge facing the port
    final travel = _iv(t, 0.02, 0.40, Curves.easeInCubic);
    final fade = 1 - _iv(t, 0.40, 0.62);

    // Glow at the port, like the connector lighting up.
    final portPulse = _iv(t, 0.0, 0.18, Curves.easeOut) * fade;
    if (portPulse > 0) {
      canvas.drawCircle(
        p,
        r * 1.1,
        Paint()
          ..shader = RadialGradient(colors: [color.withValues(alpha: 0.55 * portPulse), color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: p, radius: r * 1.1)),
      );
      // A tiny "connector" capsule hugging the edge
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(math.atan2(dir.dy, dir.dx) + math.pi / 2);
      final cap = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -6), width: r * 0.42, height: 14), const Radius.circular(7));
      canvas.drawRRect(cap, Paint()..color = color.withValues(alpha: 0.9 * portPulse));
      canvas.restore();
    }

    if (travel > 0 && fade > 0) {
      final head = Offset.lerp(p, target, travel)!;
      final tail = Offset.lerp(p, target, math.max(0, travel - 0.55))!;
      final beamShader = LinearGradient(
        colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.9 * fade), const Color(0xFFFFFFFF).withValues(alpha: fade)],
        stops: const [0, 0.8, 1],
      ).createShader(Rect.fromPoints(tail, head));
      // outer glow
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..shader = beamShader
          ..strokeWidth = r * 0.22
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.12),
      );
      // core
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..shader = beamShader
          ..strokeWidth = r * 0.05
          ..strokeCap = StrokeCap.round,
      );
      // bright head
      canvas.drawCircle(head, r * 0.07, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: fade));
      canvas.drawCircle(
        head,
        r * 0.25,
        Paint()
          ..color = color.withValues(alpha: 0.6 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
      );
    }

    // Particle stream along the path.
    final rnd = math.Random(7);
    for (var i = 0; i < 46; i++) {
      final delay = rnd.nextDouble() * 0.5;
      final speed = 0.8 + rnd.nextDouble() * 0.6;
      final lateral = (rnd.nextDouble() - 0.5) * r * 0.9;
      final s = ((travel * 1.4 - delay) * speed).clamp(0.0, 1.0);
      if (s <= 0 || s >= 1) continue;
      final pos = Offset.lerp(p, target, s)! + normal * lateral * (1 - s) * math.sin(s * math.pi + i);
      final a = (math.sin(s * math.pi)) * fade;
      canvas.drawCircle(pos, 1.5 + rnd.nextDouble() * 2.5, Paint()..color = (i.isEven ? color : const Color(0xFFFFFFFF)).withValues(alpha: a));
    }

    // Impact flash where the stream plugs into the ring.
    final flash = _iv(t, 0.36, 0.44) * (1 - _iv(t, 0.44, 0.62));
    if (flash > 0) {
      canvas.drawCircle(
        target,
        r * 0.6,
        Paint()
          ..shader = RadialGradient(colors: [const Color(0xFFFFFFFF).withValues(alpha: flash), color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: target, radius: r * 0.6)),
      );
    }
  }

  void _wireless(Canvas canvas, Size size, Offset c, double r) {
    // MagSafe-style bloom: a shimmering ring expands from the center, then contracts to the battery ring.
    final grow = _iv(t, 0.0, 0.30, Curves.easeOutCubic);
    final settle = _iv(t, 0.30, 0.46, Curves.easeInOutCubic);
    final rad = (r * 0.2 + (r * 1.9 - r * 0.2) * grow) * (1 - settle) + r * settle;
    final alpha = 1 - _iv(t, 0.46, 0.62);
    if (alpha <= 0) return;

    // soft core glow
    canvas.drawCircle(
      c,
      rad * 1.15,
      Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: 0.25 * alpha), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: rad * 1.15)),
    );
    final rect = Rect.fromCircle(center: c, radius: rad);
    final rot = t * math.pi * 4;
    final shimmer = SweepGradient(
      colors: [
        color.withValues(alpha: 0.15 * alpha),
        const Color(0xFFFFFFFF).withValues(alpha: alpha),
        color.withValues(alpha: 0.9 * alpha),
        const Color(0xFF64D2FF).withValues(alpha: 0.7 * alpha),
        color.withValues(alpha: 0.15 * alpha),
      ],
      transform: GradientRotation(rot),
    ).createShader(rect);
    canvas.drawCircle(
      c,
      rad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.28
        ..shader = shimmer
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.14),
    );
    canvas.drawCircle(
      c,
      rad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..shader = shimmer,
    );
    // orbiting sparkles
    final rnd = math.Random(3);
    for (var i = 0; i < 28; i++) {
      final ang = rnd.nextDouble() * math.pi * 2 + rot * (0.3 + rnd.nextDouble() * 0.4);
      final d = rad + (rnd.nextDouble() - 0.5) * r * 0.5;
      final pos = c + Offset(math.cos(ang), math.sin(ang)) * d;
      canvas.drawCircle(pos, 1.2 + rnd.nextDouble() * 2.2, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * rnd.nextDouble()));
    }
  }

  void _ring(Canvas canvas, Offset c, double r) {
    final appear = _iv(t, 0.34, 0.50, Curves.easeOut);
    if (appear <= 0) return;
    final fill = _iv(t, 0.40, 0.80, Curves.easeOutCubic) * (event.level.clamp(0, 100) / 100);
    final w = r * 0.17;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = color.withValues(alpha: 0.18 * appear),
    );
    if (fill > 0.001) {
      final sweep = 2 * math.pi * fill;
      // glow
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 1.6
          ..strokeCap = StrokeCap.round
          ..color = color.withValues(alpha: 0.45 * appear)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.7),
      );
      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round
          ..shader = SweepGradient(
            colors: [Color.lerp(color, const Color(0xFF000000), 0.2)!, color, const Color(0xFFE8FFEE)],
            stops: const [0, 0.85, 1],
            endAngle: math.max(sweep, 0.01),
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect),
      );
      // bright tip
      final a = -math.pi / 2 + sweep;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r, w * 0.32, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: appear));
    }
  }

  void _ripples(Canvas canvas, Offset c, double r) {
    for (var k = 0; k < 3; k++) {
      final p = _iv(t, 0.50 + k * 0.08, 0.95 + k * 0.02, Curves.easeOutCubic);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
        c,
        r * (1.1 + p * 1.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04 * (1 - p) + 0.5
          ..color = color.withValues(alpha: 0.5 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyPainter old) => old.t != t;
}
