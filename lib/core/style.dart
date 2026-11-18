import 'package:flutter/widgets.dart';

/// Apple-like dark palette.
class Palette {
  static const bg = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const card2 = Color(0xFF2C2C2E);
  static const separator = Color(0xFF38383A);
  static const label = Color(0xFFFFFFFF);
  static const secondary = Color(0xFF8E8E93);
  static const tertiary = Color(0xFF636366);
  static const red = Color(0xFFFF453A);
  static const blue = Color(0xFF0A84FF);
  static const green = Color(0xFF30D158);
  static const yellow = Color(0xFFFFD60A);
}

/// Inter text style with Apple-like display tracking and tabular digits.
TextStyle sf(
  double size, {
  FontWeight weight = FontWeight.w600,
  Color color = Palette.label,
  double? height,
  bool tabular = false,
  double? tracking,
}) {
  // Apple tightens tracking as size grows.
  final track = tracking ?? (size >= 60 ? -size * 0.035 : size >= 28 ? -size * 0.02 : size >= 17 ? -size * 0.01 : 0.0);
  return TextStyle(
    fontFamily: 'Inter',
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: track,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    leadingDistribution: TextLeadingDistribution.even,
  );
}
