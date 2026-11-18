import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';

import '../core/clock.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../widgets/analog_clock.dart';
import '../widgets/media_card.dart';
import '../widgets/tiles.dart';
import 'clock_styles_extra.dart';

bool isLandscape(BoxConstraints c) => c.maxWidth > c.maxHeight;

/// Two widgets side-by-side in landscape, stacked in portrait — like StandBy's widget view.
class SplitPage extends StatelessWidget {
  const SplitPage({super.key, required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.09;
      if (land) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad * 0.6, vertical: pad),
          child: Row(children: [
            Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad * 0.5), child: first)),
            Expanded(child: Padding(padding: EdgeInsets.symmetric(horizontal: pad * 0.5), child: second)),
          ]),
        );
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad * 1.6),
        child: Column(children: [
          Expanded(child: Padding(padding: EdgeInsets.symmetric(vertical: pad * 0.5), child: first)),
          Expanded(child: Padding(padding: EdgeInsets.symmetric(vertical: pad * 0.5), child: second)),
        ]),
      );
    });
  }
}

class AnalogTile extends StatelessWidget {
  const AnalogTile({super.key, this.face = AnalogFace.numerals});
  final AnalogFace face;

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return Center(
      child: AnalogClock(face: face, secondColor: s.accent == Accents.white ? Accents.orange : s.accent, smooth: s.smoothSeconds),
    );
  }
}

// ───────────────────────── Smart: time + date + weather ─────────────────────────

class SmartPage extends StatelessWidget {
  const SmartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.08;
      final header = Row(children: [
        Expanded(
          child: ClockBuilder(
            builder: (context, now) => Text(
              s.t.longDate(now),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: sf(land ? 24 : 20, weight: FontWeight.w700, color: Palette.secondary),
            ),
          ),
        ),
        const BatteryPill(),
      ]);
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, pad * (land ? 0.7 : 1.6), pad, pad * (land ? 0.7 : 1.6)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            Expanded(
              child: Center(
                child: Fit(
                  child: land
                      ? const DigitalTime(size: 220, weight: FontWeight.w800)
                      : _StackedTime(color: s.accent),
                ),
              ),
            ),
            SizedBox(
              height: land ? 34 : 30,
              child: const Fit(alignment: Alignment.centerLeft, child: WeatherInline(size: 24)),
            ),
            if (!land) ...[
              SizedBox(height: pad * 0.6),
              const SizedBox(height: 96, child: Fit(alignment: Alignment.centerLeft, child: HourlyRow(count: 5))),
            ],
          ],
        ),
      );
    });
  }
}

class _StackedTime extends StatelessWidget {
  const _StackedTime({required this.color, this.weight = FontWeight.w800});
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return ClockBuilder(builder: (context, now) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text(s.use24h ? two(now.hour) : formatHour(now, false).padLeft(2, '0'),
            style: sf(220, weight: weight, color: color, height: 0.98, tabular: true)),
        Text(two(now.minute), style: sf(220, weight: weight, color: color, height: 0.98, tabular: true)),
      ]);
    });
  }
}

// ───────────────────────── Clock styles (vertical swipe) ─────────────────────────

class ClockStylesPage extends StatefulWidget {
  const ClockStylesPage({super.key});
  static const count = 10;

  @override
  State<ClockStylesPage> createState() => _ClockStylesPageState();
}

class _ClockStylesPageState extends State<ClockStylesPage> {
  late final PageController _pc;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = SettingsScope.read(context);
      final i = s.clockStyle.clamp(0, ClockStylesPage.count - 1);
      if (_pc.hasClients && i != 0) _pc.jumpToPage(i);
      setState(() => _index = i);
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return Stack(children: [
      PageView(
        controller: _pc,
        scrollDirection: Axis.vertical,
        onPageChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
          s.clockStyle = i;
        },
        children: const [
          _DigitalStyle(),
          _AnalogStyle(),
          SolarStyle(),
          FloatStyle(),
          _FlipStyle(),
          _GlowStyle(),
          WordsStyle(),
          DotMatrixStyle(),
          OutlineStyle(),
          _RingStyle(),
        ],
      ),
      Positioned(
        right: 10,
        top: 0,
        bottom: 0,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < ClockStylesPage.count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(vertical: 3),
                width: 5,
                height: i == _index ? 16 : 5,
                decoration: BoxDecoration(
                  color: i == _index ? Palette.label.withValues(alpha: 0.7) : Palette.label.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _DigitalStyle extends StatelessWidget {
  const _DigitalStyle();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.06;
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Center(
          child: Fit(
            child: land
                ? const DigitalTime(size: 240, weight: FontWeight.w800)
                : _StackedTime(color: s.accent, weight: FontWeight.w800),
          ),
        ),
      );
    });
  }
}

class _AnalogStyle extends StatelessWidget {
  const _AnalogStyle();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.07;
      final clock = AnalogClock(
        face: AnalogFace.numerals,
        secondColor: s.accent == Accents.white ? Accents.orange : s.accent,
        smooth: s.smoothSeconds,
      );
      final date = ClockBuilder(
        builder: (context, now) => Column(
          crossAxisAlignment: land ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(s.t.weekday(now.weekday), style: sf(34, weight: FontWeight.w700, color: Palette.red)),
            Text('${now.day} ${s.t.month(now.month)}', style: sf(34, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            const WeatherInline(size: 22, showCity: false),
          ],
        ),
      );
      return Padding(
        padding: EdgeInsets.all(pad),
        child: land
            ? Row(children: [
                Expanded(flex: 5, child: Center(child: clock)),
                SizedBox(width: pad),
                Expanded(flex: 4, child: Fit(alignment: Alignment.centerLeft, child: date)),
              ])
            : Column(children: [
                const Spacer(),
                clock,
                SizedBox(height: pad),
                SizedBox(height: c.maxHeight * 0.16, child: Fit(child: date)),
                const Spacer(),
              ]),
      );
    });
  }
}

class _FlipStyle extends StatelessWidget {
  const _FlipStyle();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.07;
      return ClockBuilder(builder: (context, now) {
        final h = s.use24h ? two(now.hour) : formatHour(now, false).padLeft(2, '0');
        final m = two(now.minute);
        final cards = [_FlipCard(text: h, color: Palette.label), _FlipCard(text: m, color: s.accent)];
        return Padding(
          padding: EdgeInsets.all(pad),
          child: land
              ? Row(children: [Expanded(child: cards[0]), SizedBox(width: pad * 0.5), Expanded(child: cards[1])])
              : Column(children: [Expanded(child: cards[0]), SizedBox(height: pad * 0.5), Expanded(child: cards[1])]),
        );
      });
    });
  }
}

class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232326), Color(0xFF161618)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Fit(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, -0.08), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Text(text, key: ValueKey(text), style: sf(220, weight: FontWeight.w800, color: color, height: 1.0, tabular: true)),
            ),
          ),
        ),
        Center(child: Container(height: 3, color: const Color(0xFF000000))),
      ]),
    );
  }
}

class _GlowStyle extends StatelessWidget {
  const _GlowStyle();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final a = s.accent;
    final light = Color.lerp(a, const Color(0xFFFFFFFF), 0.55)!;
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.06;
      Widget digits(Widget child) => ShaderMask(
            shaderCallback: (r) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light, a],
            ).createShader(r),
            child: child,
          );
      final glowShadow = [Shadow(color: a.withValues(alpha: 0.55), blurRadius: 60)];
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Center(
          child: Fit(
            child: ClockBuilder(builder: (context, now) {
              final st = sf(230, weight: FontWeight.w900, color: Palette.label, height: 1.0, tabular: true).copyWith(shadows: glowShadow);
              final h = formatHour(now, s.use24h);
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Text(s.t.longDate(now).toUpperCase(),
                    style: sf(26, weight: FontWeight.w800, color: light.withValues(alpha: 0.9), tracking: 2)),
                const SizedBox(height: 8),
                digits(land
                    ? Text('$h:${two(now.minute)}', style: st)
                    : Column(children: [Text(h.padLeft(2, '0'), style: st), Text(two(now.minute), style: st)])),
              ]);
            }),
          ),
        ),
      );
    });
  }
}

class _RingStyle extends StatelessWidget {
  const _RingStyle();

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final pad = c.biggest.shortestSide * 0.08;
      return Padding(
        padding: EdgeInsets.all(pad),
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: ClockBuilder(builder: (context, now) {
              return CustomPaint(
                painter: _RingPainter(now.second, s.accent),
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Fit(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(formatTime(now, s.use24h), style: sf(120, weight: FontWeight.w800, height: 1.0, tabular: true)),
                      const SizedBox(height: 6),
                      Text(s.t.longDate(now), style: sf(22, weight: FontWeight.w700, color: Palette.secondary)),
                    ]),
                  ),
                ),
              );
            }),
          ),
        ),
      );
    });
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.second, this.accent);
  final int second;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * math.pi - math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final active = i <= second;
      final major = i % 5 == 0;
      canvas.drawLine(
        c + dir * r * (major ? 0.86 : 0.89),
        c + dir * r * 0.97,
        Paint()
          ..color = active ? accent : const Color(0xFF2C2C2E)
          ..strokeWidth = r * (major ? 0.028 : 0.018)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.second != second || old.accent != accent;
}

// ───────────────────────── Media ─────────────────────────

class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    return LayoutBuilder(builder: (context, c) {
      final land = isLandscape(c);
      final pad = c.biggest.shortestSide * 0.06;
      final header = ClockBuilder(
        builder: (context, now) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(formatTime(now, s.use24h), style: sf(land ? 40 : 44, weight: FontWeight.w800, color: s.accent, tabular: true)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(s.t.longDate(now),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: sf(20, weight: FontWeight.w700, color: Palette.secondary)),
            ),
            const BatteryPill(),
          ],
        ),
      );
      return Padding(
        padding: EdgeInsets.fromLTRB(pad, pad * (land ? 0.5 : 1.4), pad, pad * 0.5),
        child: Column(children: [
          header,
          Expanded(child: MediaPanel(vertical: !land)),
        ]),
      );
    });
  }
}
