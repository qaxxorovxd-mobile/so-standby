import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/clock.dart';
import '../core/services_scope.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../widgets/analog_clock.dart';
import '../widgets/tiles.dart';
import 'more_pages.dart';
import 'pages.dart';
import 'settings_sheet.dart';

class StandbyScreen extends StatefulWidget {
  const StandbyScreen({super.key});

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen> with WidgetsBindingObserver {
  static const _pageCount = 13;
  static const _loopBase = 600; // large multiple of page count for infinite swiping

  late final PageController _pc;
  int _page = 0;
  bool _chrome = false; // dots + settings button visible
  bool _hint = false;
  bool? _nightOverride;
  Timer? _chromeTimer;
  late AppSettings _s;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _s = SettingsScope.read(context);
    _page = _s.lastPage.clamp(0, _pageCount - 1);
    _pc = PageController(initialPage: _loopBase * _pageCount + _page);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyWakelock();
    _s.addListener(_applyWakelock);
    if (_s.getString('hintShown') == null) {
      _hint = true;
      _s.setString('hintShown', '1');
      Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _hint = false);
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sv = Services.of(context);
      sv.weather.refresh();
      sv.media.checkAccess();
    });
  }

  void _applyWakelock() {
    if (_s.keepAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      final sv = Services.of(context);
      sv.weather.refresh();
      sv.media.checkAccess();
      _applyWakelock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _s.removeListener(_applyWakelock);
    _chromeTimer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  void _showChrome([Duration d = const Duration(seconds: 3)]) {
    _chromeTimer?.cancel();
    setState(() => _chrome = true);
    _chromeTimer = Timer(d, () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  Future<void> _openSettings() async {
    HapticFeedback.mediumImpact();
    _chromeTimer?.cancel();
    setState(() => _chrome = false);
    await showSettingsSheet(context);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  bool _isNight(DateTime now) {
    if (_nightOverride != null) return _nightOverride!;
    return switch (_s.nightMode) {
      NightMode.off => false,
      NightMode.on => true,
      NightMode.auto => now.hour >= 22 || now.hour < 6,
    };
  }

  Widget _pageFor(int i) => switch (i) {
        0 => const SmartPage(),
        1 => const ClockStylesPage(),
        2 => const SplitPage(first: AnalogTile(), second: WeatherTile()),
        3 => const SplitPage(first: DateTile(), second: WeatherTile()),
        4 => const SplitPage(first: AnalogTile(face: AnalogFace.minimal), second: CalendarTile()),
        5 => const SplitPage(first: DigitalDateTile(), second: CalendarTile()),
        6 => const ForecastPage(),
        7 => const WorldClockPage(),
        8 => const SplitPage(first: AnalogTile(), second: BatteryTile()),
        9 => const DayProgressPage(),
        10 => const SplitPage(first: DateTile(), second: CalendarTile()),
        11 => const StopwatchPage(),
        _ => const MediaPage(),
      };

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final t = s.t;

    final pages = PageView.builder(
      controller: _pc,
      onPageChanged: (i) {
        final p = i % _pageCount;
        HapticFeedback.selectionClick();
        setState(() => _page = p);
        s.lastPage = p;
        _showChrome(const Duration(milliseconds: 1600));
      },
      itemBuilder: (context, i) => _pageFor(i % _pageCount),
    );

    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: Palette.bg,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showChrome,
          onLongPress: _openSettings,
          child: ClockBuilder(builder: (context, now) {
            final night = _isNight(now);
            Widget content = _BurnInShift(enabled: s.burnIn, minute: now.hour * 60 + now.minute, child: pages);
            if (night) {
              content = ColorFiltered(colorFilter: _nightFilter, child: content);
            }
            return Stack(children: [
              Positioned.fill(child: content),
              // Page dots
              Positioned(
                left: 0,
                right: 0,
                bottom: 14,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _chrome ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < _pageCount; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _page ? 18 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: (night ? Palette.red : Palette.label).withValues(alpha: i == _page ? 0.8 : 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
              // Settings button
              Positioned(
                top: 16,
                right: 16,
                child: SafeArea(
                  child: IgnorePointer(
                    ignoring: !_chrome,
                    child: AnimatedOpacity(
                      opacity: _chrome ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: _RoundButton(
                        icon: CupertinoIcons.gear_alt_fill,
                        onTap: _openSettings,
                        color: night ? Palette.red : Palette.label,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  child: IgnorePointer(
                    ignoring: !_chrome,
                    child: AnimatedOpacity(
                      opacity: _chrome ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: _RoundButton(
                        icon: night ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _nightOverride = !night);
                          _showChrome();
                        },
                        color: night ? Palette.red : Palette.label,
                      ),
                    ),
                  ),
                ),
              ),
              // First-run hint
              Positioned(
                left: 0,
                right: 0,
                bottom: 40,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _hint ? 1 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(color: Palette.card.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(100)),
                        child: Text('${t.hintSwipe}  ·  ${t.hintLongPress}',
                            style: sf(14, weight: FontWeight.w600, color: Palette.label)),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          }),
        ),
      ),
    );
  }
}

/// Maps luminance to pure red — StandBy night mode.
const _nightFilter = ColorFilter.matrix(<double>[
  0.40, 0.75, 0.15, 0, 0, //
  0.00, 0.00, 0.00, 0, 0,
  0.00, 0.00, 0.00, 0, 0,
  0.00, 0.00, 0.00, 1, 0,
]);

class _BurnInShift extends StatelessWidget {
  const _BurnInShift({required this.enabled, required this.minute, required this.child});
  final bool enabled;
  final int minute;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Offset target = Offset.zero;
    if (enabled) {
      final rnd = math.Random(minute * 7919);
      target = Offset(rnd.nextDouble() * 8 - 4, rnd.nextDouble() * 8 - 4);
    }
    return TweenAnimationBuilder<Offset>(
      tween: Tween(end: target),
      duration: const Duration(seconds: 3),
      curve: Curves.easeInOut,
      child: child,
      builder: (context, o, child) => Transform.translate(offset: o, child: child),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, required this.color});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: Palette.card.withValues(alpha: 0.9), shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: color),
        ),
      );
}
