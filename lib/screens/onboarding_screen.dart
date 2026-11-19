import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../core/services_scope.dart';
import '../core/settings.dart';
import '../core/style.dart';
import '../widgets/ios_surface.dart';
import 'standby_screen.dart';

/// Apple-style welcome + permission screen shown on first launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.fromSettings = false});
  final bool fromSettings;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _location = false;
  bool _media = false;
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
    _refresh();
    if (!widget.fromSettings) {
      // Ask for location right away on first launch.
      Future.delayed(const Duration(milliseconds: 900), () async {
        if (!mounted) return;
        final p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) await _requestLocation();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intro.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final p = await Geolocator.checkPermission();
    if (!mounted) return;
    final m = await Services.of(context).media.checkAccess();
    if (!mounted) return;
    setState(() {
      _location = p == LocationPermission.always || p == LocationPermission.whileInUse;
      _media = m;
    });
  }

  Future<void> _requestLocation() async {
    HapticFeedback.lightImpact();
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    await _refresh();
    if (_location && mounted) Services.of(context).weather.refresh(force: true);
  }

  Future<void> _requestMedia() async {
    HapticFeedback.lightImpact();
    await Services.of(context).media.openAccessSettings();
  }

  void _continue() {
    HapticFeedback.mediumImpact();
    final s = SettingsScope.of(context);
    s.onboarded = true;
    if (widget.fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: Motion.duration(context, 600),
        pageBuilder: (_, _, _) => const StandbyScreen(),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  Widget _stagger(int i, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final start = (i * 0.09).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.5).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (context, child) => Opacity(
        opacity: anim.value,
        child: Transform.translate(offset: Offset(0, 24 * (1 - anim.value)), child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final t = s.t;

    final hero = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stagger(
          0,
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Color(0x40FFFFFF), blurRadius: 40, spreadRadius: -12)],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset('assets/icon/icon.png', fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 26),
        _stagger(1, Text(t.welcomeTitle, style: sf(40, weight: FontWeight.w800))),
        const SizedBox(height: 10),
        _stagger(
          2,
          Text(
            t.welcomeSubtitle,
            textAlign: TextAlign.center,
            style: sf(17, weight: FontWeight.w500, color: Palette.secondary, height: 1.35),
          ),
        ),
      ],
    );

    final perms = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stagger(
          3,
          _PermRow(
            icon: CupertinoIcons.location_fill,
            colors: const [Color(0xFF4FA3FF), Color(0xFF0A84FF)],
            title: t.permLocationTitle,
            body: t.permLocationBody,
            granted: _location,
            grantedLabel: t.granted,
            actionLabel: t.allow,
            onTap: _requestLocation,
          ),
        ),
        const SizedBox(height: 12),
        _stagger(
          4,
          _PermRow(
            icon: CupertinoIcons.music_note_2,
            colors: const [Color(0xFFFF6482), Color(0xFFFF2D55)],
            title: t.permMediaTitle,
            body: t.permMediaBody,
            granted: _media,
            grantedLabel: t.granted,
            actionLabel: t.allow,
            onTap: _requestMedia,
          ),
        ),
        const SizedBox(height: 14),
        _stagger(
          5,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.lock_fill, size: 13, color: Palette.tertiary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  t.privacyNote,
                  style: sf(13, weight: FontWeight.w500, color: Palette.tertiary),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final buttons = _stagger(
      6,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              color: Palette.label,
              borderRadius: BorderRadius.circular(16),
              padding: const EdgeInsets.symmetric(vertical: 17),
              onPressed: _continue,
              child: Text(
                t.continueBtn,
                style: sf(17, weight: FontWeight.w700, color: Palette.bg),
              ),
            ),
          ),
          if (!(_location && _media))
            CupertinoButton(
              onPressed: _continue,
              child: Text(
                t.later,
                style: sf(16, weight: FontWeight.w600, color: Palette.blue),
              ),
            ),
        ],
      ),
    );

    return ColoredBox(
      color: Palette.bg,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final land = c.maxWidth > c.maxHeight;
            if (land) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(child: SingleChildScrollView(child: hero)),
                    ),
                    const SizedBox(width: 32),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [perms, const SizedBox(height: 18), buttons]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [hero, const SizedBox(height: 40), perms]),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: buttons),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PermRow extends StatelessWidget {
  const _PermRow({
    required this.icon,
    required this.colors,
    required this.title,
    required this.body,
    required this.granted,
    required this.grantedLabel,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> colors;
  final String title, body, grantedLabel, actionLabel;
  final bool granted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: AnimatedContainer(
        duration: Motion.duration(context),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: granted ? Color.lerp(Palette.card, Palette.green, 0.07) : Palette.card,
          border: Border.all(color: granted ? Palette.green.withValues(alpha: 0.22) : const Color(0x0FFFFFFF), width: 0.5),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Palette.label, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: sf(17, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: sf(14, weight: FontWeight.w500, color: Palette.secondary, height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: Motion.duration(context, 300),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: granted
                  ? Container(
                      key: const ValueKey('ok'),
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(color: Palette.green, shape: BoxShape.circle),
                      child: const Icon(CupertinoIcons.checkmark_alt, size: 20, color: Palette.label),
                    )
                  : Container(
                      key: const ValueKey('ask'),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Palette.blue, borderRadius: BorderRadius.circular(100)),
                      child: Text(actionLabel, style: sf(14, weight: FontWeight.w700)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
