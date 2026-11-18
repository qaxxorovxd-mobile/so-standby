import 'package:flutter_test/flutter_test.dart';
import 'package:so_standby/core/clock.dart';

void main() {
  test('formats time', () {
    final d = DateTime(2026, 1, 1, 13, 5);
    expect(formatTime(d, true), '13:05');
    expect(formatTime(d, false), '1:05');
  });
}
