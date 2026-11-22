import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/style.dart';
import '../services/notifications.dart';

/// A finite capsule → card → capsule animation. The rest of StandBy stays interactive.
class NotificationBanner extends StatefulWidget {
  const NotificationBanner({
    super.key,
    required this.notice,
    required this.accent,
    required this.onDismiss,
    required this.onOpen,
    this.night = false,
    this.pendingCount = 0,
  });
  final StandbyNotice notice;
  final Color accent;
  final bool night;
  final int pendingCount;
  final VoidCallback onDismiss;
  final Future<bool> Function() onOpen;

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  Timer? _hold;
  bool _started = false, _closing = false, _opening = false;
  Offset _drag = Offset.zero;

  bool get _reduce => MediaQuery.disableAnimationsOf(context);

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 380),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      if (_reduce && _motion.isAnimating) _motion.value = 1;
      return;
    }
    _started = true;
    if (_reduce) {
      _motion.value = 1;
      _scheduleDismiss();
    } else {
      _motion.forward().then((_) {
        if (mounted && !_closing) _scheduleDismiss();
      });
    }
  }

  @override
  void didUpdateWidget(covariant NotificationBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.notice, widget.notice) && !_closing) _scheduleDismiss();
  }

  void _scheduleDismiss() {
    _hold?.cancel();
    _hold = Timer(MediaQuery.accessibleNavigationOf(context) ? const Duration(seconds: 12) : const Duration(seconds: 6), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    _hold?.cancel();
    if (!_reduce) {
      try {
        await _motion.reverse().orCancel;
      } on TickerCanceled {
        return;
      }
    }
    if (mounted) widget.onDismiss();
  }

  Future<void> _open() async {
    if (_opening || _closing || !widget.notice.canOpen) return;
    _opening = true;
    final opened = await widget.onOpen();
    if (!mounted) return;
    _opening = false;
    if (opened) await _dismiss();
  }

  @override
  void dispose() {
    _hold?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.night ? Palette.red : widget.accent;
    final label = widget.night ? const Color(0xFFFF7771) : Palette.label;
    final secondary = widget.night ? Palette.red.withValues(alpha: .7) : const Color(0xFFB6B6BE);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(510.0, constraints.maxWidth);
            const height = 144.0;
            return Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final t = _motion.value;
                  final appear = const Interval(0, .3, curve: Curves.easeOut).transform(t);
                  final expand = const Interval(.18, .85, curve: Curves.easeOutCubic).transform(t);
                  final reveal = const Interval(.43, .88, curve: Curves.easeOut).transform(t);
                  final travel = Curves.easeOutBack.transform((t / .65).clamp(0, 1));
                  final w = ui.lerpDouble(64, width, expand)!;
                  final h = ui.lerpDouble(64, height, expand)!;
                  return Opacity(
                    opacity: appear,
                    child: Transform.translate(
                      offset: Offset(0, -90 * (1 - travel)),
                      child: Semantics(
                        liveRegion: true,
                        label: '${widget.notice.app}. ${widget.notice.title}. ${widget.notice.body}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.notice.canOpen ? _open : null,
                          onPanStart: (_) {
                            _drag = Offset.zero;
                            _hold?.cancel();
                          },
                          onPanUpdate: (details) => _drag += details.delta,
                          onPanEnd: (_) {
                            if (_drag.dx.abs() > 45 || _drag.dy < -22) {
                              _dismiss();
                            } else if (!_closing) {
                              _scheduleDismiss();
                            }
                          },
                          onPanCancel: () {
                            if (!_closing) _scheduleDismiss();
                          },
                          child: Container(
                            width: w,
                            height: h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(ui.lerpDouble(32, 30, expand)!),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: (widget.night ? .04 : .14) * math.sin(t * math.pi)),
                                  blurRadius: 42,
                                  spreadRadius: 5,
                                ),
                                const BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 12)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(ui.lerpDouble(32, 30, expand)!),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: widget.night
                                          ? const [Color(0xF5221112), Color(0xF5100809)]
                                          : const [Color(0xF23A3A40), Color(0xF21C1C20)],
                                    ),
                                    borderRadius: BorderRadius.circular(ui.lerpDouble(32, 30, expand)!),
                                    border: Border.all(color: color.withValues(alpha: widget.night ? .12 : .22), width: .7),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Opacity(
                                          opacity: reveal,
                                          child: OverflowBox(
                                            alignment: Alignment.topLeft,
                                            minWidth: width,
                                            maxWidth: width,
                                            minHeight: height,
                                            maxHeight: height,
                                            child: Padding(
                                              padding: const EdgeInsets.fromLTRB(84, 18, 42, 18),
                                              child: ExcludeSemantics(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            widget.notice.app,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: sf(12, weight: FontWeight.w600, color: secondary),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          widget.pendingCount > 0 ? '+${widget.pendingCount}' : 'now',
                                                          style: sf(11, color: secondary),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 7),
                                                    Text(
                                                      widget.notice.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: sf(18, weight: FontWeight.w700, color: label, height: 1.2),
                                                    ),
                                                    const SizedBox(height: 5),
                                                    Text(
                                                      widget.notice.body,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: sf(14, weight: FontWeight.w400, color: secondary, height: 1.35),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: ui.lerpDouble(10, 18, expand),
                                        top: ui.lerpDouble(10, 22, expand),
                                        child: Transform.scale(
                                          scale: 1 + .10 * math.sin(t * math.pi),
                                          child: Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: .17),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: widget.notice.icon != null && !widget.night
                                                ? Image.memory(
                                                    widget.notice.icon!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => Icon(CupertinoIcons.bell_fill, color: color, size: 25),
                                                  )
                                                : Icon(
                                                    widget.notice.redacted ? CupertinoIcons.lock_fill : CupertinoIcons.bell_fill,
                                                    color: color,
                                                    size: 25,
                                                  ),
                                          ),
                                        ),
                                      ),
                                      if (reveal > .9)
                                        Positioned(
                                          right: 1,
                                          top: 5,
                                          child: Semantics(
                                            label: 'Dismiss notification',
                                            button: true,
                                            child: CupertinoButton(
                                              padding: const EdgeInsets.all(12),
                                              minimumSize: const Size(44, 44),
                                              onPressed: _dismiss,
                                              child: Icon(CupertinoIcons.xmark, size: 13, color: secondary),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 8,
                                        left: 0,
                                        right: 0,
                                        child: Opacity(
                                          opacity: reveal * .55,
                                          child: Center(
                                            child: Container(
                                              width: 25,
                                              height: 3,
                                              decoration: BoxDecoration(color: secondary, borderRadius: BorderRadius.circular(3)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
