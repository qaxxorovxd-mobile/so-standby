import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';

import '../core/style.dart';

/// Shared timing keeps small interactions and larger transitions consistent.
abstract final class Motion {
  static const curve = Curves.easeOutCubic;
  static Duration duration(BuildContext context, [int milliseconds = 420]) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : Duration(milliseconds: milliseconds);
}

/// Blur is confined to small controls, keeping the always-on display inexpensive.
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = 28});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xD938383C), Color(0xD91C1C1E)],
          ),
          border: Border.all(color: const Color(0x20FFFFFF), width: 0.5),
        ),
        child: child,
      ),
    ),
  );
}

class ChromeReveal extends StatelessWidget {
  const ChromeReveal({super.key, required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !visible,
    child: ExcludeSemantics(
      excluding: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.16),
        duration: Motion.duration(context),
        curve: Motion.curve,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: Motion.duration(context, 280),
          child: AnimatedScale(scale: visible ? 1 : 0.92, duration: Motion.duration(context), curve: Motion.curve, child: child),
        ),
      ),
    ),
  );
}

/// Content follows the gesture; no timer or ticker runs after a swipe settles.
class PageDepth extends StatelessWidget {
  const PageDepth({super.key, required this.controller, required this.index, required this.child});
  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: controller,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final page = controller.hasClients && controller.position.hasContentDimensions
            ? controller.page ?? controller.initialPage.toDouble()
            : controller.initialPage.toDouble();
        final distance = (page - index).abs().clamp(0.0, 1.0);
        return Transform.scale(
          scale: 1 - distance * 0.065,
          child: Opacity(opacity: 1 - distance * 0.35, child: child),
        );
      },
    );
  }
}

class StandbyPanel extends StatelessWidget {
  const StandbyPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Container(
      padding: EdgeInsets.all(constraints.biggest.shortestSide * 0.065),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171719), Color(0xFF09090B)],
        ),
        border: Border.all(color: Palette.label.withValues(alpha: 0.055), width: 0.5),
      ),
      child: child,
    ),
  );
}
