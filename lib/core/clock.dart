import 'dart:async';

import 'package:flutter/widgets.dart';

/// A single app-wide clock that ticks exactly on each second boundary.
class Clock extends ValueNotifier<DateTime> {
  Clock() : super(DateTime.now()) {
    _schedule();
  }

  Timer? _timer;

  void _schedule() {
    final now = DateTime.now();
    final wait = Duration(milliseconds: 1000 - now.millisecond, microseconds: -now.microsecond);
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () {
      value = DateTime.now();
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static final instance = Clock();
}

String two(int v) => v.toString().padLeft(2, '0');

/// Formats hours honoring 12/24h preference. In 12h mode returns no leading zero (Apple style).
String formatHour(DateTime d, bool use24h) {
  if (use24h) return two(d.hour);
  final h = d.hour % 12;
  return (h == 0 ? 12 : h).toString();
}

String formatTime(DateTime d, bool use24h, {bool seconds = false}) =>
    '${formatHour(d, use24h)}:${two(d.minute)}${seconds ? ':${two(d.second)}' : ''}';

String amPm(DateTime d) => d.hour < 12 ? 'AM' : 'PM';

/// Rebuilds [builder] every second.
class ClockBuilder extends StatelessWidget {
  const ClockBuilder({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
        valueListenable: Clock.instance,
        builder: (context, now, _) => builder(context, now),
      );
}
