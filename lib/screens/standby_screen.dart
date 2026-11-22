import 'dart:async';
import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/clock.dart';
import '../core/services_scope.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../services/power.dart';
import '../services/notifications.dart';
import '../widgets/notification_banner.dart';
import '../widgets/analog_clock.dart';
import '../widgets/charging_overlay.dart';
import '../widgets/tiles.dart';
import '../widgets/ios_surface.dart';
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

  final _notificationService = NotificationService();
  final _notices = NoticeQueue();
  bool _foreground = true;
  bool _settingsOpen = false;

  bool get _canNotify => _foreground && !_settingsOpen && _charge == null && _s.notificationAnimation;

  void _configureNotifications() {
    if (!_canNotify) _notices.clear();
    // Remove already-visible message text immediately when previews are disabled.
    if (!_s.notificationPreviews) _notices.clear();
    unawaited(_notificationService.configure(enabled: _canNotify, previews: _s.notificationPreviews));
  }

  void _onNotification(Map<Object?, Object?> event) {
    if (!mounted) return;
    switch (event['type']) {
      case 'clear':
        _notices.clear();
      case 'removed':
        _notices.remove(event['key'] as String? ?? '');
      case 'posted':
        if (_canNotify && (ModalRoute.of(context)?.isCurrent ?? false)) {
          _notices.add(StandbyNotice.fromMap(event));
        }
    }
  }

  // Charging animation
  static const _batteryPage = 8;
  StreamSubscription<ChargeEvent>? _powerSub;
  ChargeEvent? _charge;
  int? _returnTo; // absolute PageView index to go back to
  bool _back = false;
  Timer? _backTimer;

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
    _s.addListener(_configureNotifications);
    _notificationService.listen(_onNotification);
    _configureNotifications();
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
      _powerSub = sv.power.events.listen(_onCharge);
    });
  }

  void _onCharge(ChargeEvent e) {
    if (!mounted || !_s.chargeAnimation || _charge != null) return;
    // Close any open sheet/route so the animation is visible.
    Navigator.of(context).popUntil((r) => r.isFirst);
    _chromeTimer?.cancel();
    _backTimer?.cancel();
    final cur = _pc.hasClients ? (_pc.page ?? _pc.initialPage.toDouble()).round() : _pc.initialPage;
    final target = cur - (cur % _pageCount) + _batteryPage;
    _returnTo = cur % _pageCount == _batteryPage ? null : cur;
    if (_pc.hasClients && cur != target) _pc.jumpToPage(target);
    setState(() {
      _chrome = false;
      _back = false;
      _charge = e;
    });
    _configureNotifications();
  }

  void _onChargeDone() {
    if (!mounted) return;
    setState(() {
      _charge = null;
      _back = _returnTo != null;
    });
    _configureNotifications();
    if (_back) {
      _backTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _back = false);
      });
    }
  }

  void _goBack() {
    final to = _returnTo;
    _backTimer?.cancel();
    setState(() => _back = false);
    if (to == null || !_pc.hasClients) return;
    HapticFeedback.lightImpact();
    _pc.animateToPage(to, duration: const Duration(milliseconds: 550), curve: Curves.easeOutCubic);
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
    _foreground = state == AppLifecycleState.resumed;
    _configureNotifications();
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
    _s.removeListener(_configureNotifications);
    _notificationService.dispose();
    _notices.dispose();
    _chromeTimer?.cancel();
    _backTimer?.cancel();
    _powerSub?.cancel();
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
    _settingsOpen = true;
    _notices.clear();
    _configureNotifications();
    final previewNotification = await showSettingsSheet(context);
    if (!mounted) return;
    _settingsOpen = false;
    _configureNotifications();
    if (previewNotification == true && _foreground && _charge == null) {
      _notices.add(StandbyNotice.preview());
    }
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
    4 => const SplitPage(
      first: AnalogTile(face: AnalogFace.minimal),
      second: CalendarTile(),
    ),
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
      physics: const BouncingScrollPhysics(),
      onPageChanged: (i) {
        final p = i % _pageCount;
        HapticFeedback.selectionClick();
        setState(() => _page = p);
        s.lastPage = p;
        if (_charge == null) _showChrome(const Duration(milliseconds: 1600));
      },
      itemBuilder: (context, i) => PageDepth(controller: _pc, index: i, child: _pageFor(i % _pageCount)),
    );

    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: Palette.bg,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showChrome,
          onLongPress: _openSettings,
          child: ClockBuilder(
            builder: (context, now) {
              final night = _isNight(now);
              Widget content = Stack(
                children: [
                  Positioned.fill(
                    child: _BurnInShift(enabled: s.burnIn, minute: now.hour * 60 + now.minute, child: pages),
                  ),
                  if (_charge != null)
                    Positioned.fill(
                      child: ChargingOverlay(key: ObjectKey(_charge), event: _charge!, onDone: _onChargeDone),
                    ),
                ],
              );
              if (night) {
                content = ColorFiltered(colorFilter: _nightFilter, child: content);
              }
              return Stack(
                children: [
                  Positioned.fill(child: content),
                  // "Back" pill after the charging animation (visible for 3 s)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: SafeArea(
                      child: Center(
                        child: IgnorePointer(
                          ignoring: !_back,
                          child: AnimatedSlide(
                            offset: _back ? Offset.zero : const Offset(-1.2, 0),
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutBack,
                            child: AnimatedOpacity(
                              opacity: _back ? 1 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: _BackPill(onTap: _goBack, color: night ? Palette.red : Palette.label),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // A single floating control capsule keeps the display uncluttered.
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: ChromeReveal(
                          visible: _chrome,
                          child: GlassSurface(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _RoundButton(
                                    label: t.nightMode,
                                    icon: night ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() => _nightOverride = !night);
                                      _showChrome();
                                    },
                                    color: night ? Palette.red : Palette.label,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Semantics(
                                      label: 'Page ${_page + 1} of $_pageCount',
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          for (var i = 0; i < _pageCount; i++)
                                            AnimatedContainer(
                                              duration: Motion.duration(context, 350),
                                              curve: Motion.curve,
                                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                              width: i == _page ? 16 : 4,
                                              height: 4,
                                              decoration: BoxDecoration(
                                                color: (night ? Palette.red : Palette.label).withValues(alpha: i == _page ? 0.95 : 0.24),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _RoundButton(
                                    label: t.settings,
                                    icon: CupertinoIcons.gear_alt_fill,
                                    onTap: _openSettings,
                                    color: night ? Palette.red : Palette.label,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // First-run hint
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 84,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _hint ? 1 : 0,
                        duration: const Duration(milliseconds: 500),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            decoration: BoxDecoration(
                              color: Palette.card.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${t.hintSwipe}  ·  ${t.hintLongPress}',
                              textAlign: TextAlign.center,
                              style: sf(14, weight: FontWeight.w600, color: Palette.label),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ListenableBuilder(
                      listenable: _notices,
                      builder: (context, _) {
                        final notice = _notices.current;
                        if (notice == null) return const SizedBox.shrink();
                        return NotificationBanner(
                          key: ValueKey(notice.key),
                          notice: notice,
                          accent: s.accent,
                          night: night,
                          pendingCount: _notices.pendingCount,
                          onDismiss: () {
                            if (_notices.current?.key == notice.key) _notices.advance();
                          },
                          onOpen: () => _notificationService.open(notice.key),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
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
      duration: Motion.duration(context, 3000),
      curve: Curves.easeInOut,
      child: child,
      builder: (context, o, child) => Transform.translate(offset: o, child: child),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, required this.color, required this.label});
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: CupertinoButton(
      padding: const EdgeInsets.all(12),
      minimumSize: const Size(44, 44),
      onPressed: onTap,
      child: AnimatedSwitcher(
        duration: Motion.duration(context, 300),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(icon, key: ValueKey(icon), size: 20, color: color),
      ),
    ),
  );
}

class _BackPill extends StatelessWidget {
  const _BackPill({required this.onTap, required this.color});
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(left: 14),
      padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
      decoration: BoxDecoration(
        color: const Color(0xE62C2C2E),
        borderRadius: BorderRadius.circular(100),
        boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 20)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.chevron_back, size: 20, color: color),
          const SizedBox(width: 4),
          Text(
            'Back',
            style: sf(17, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    ),
  );
}
