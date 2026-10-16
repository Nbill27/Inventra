import 'package:flutter/material.dart';

/// Draft theme, built without a design direction: there is no `DESIGN.md` and
/// the PRD says nothing about visual identity. Only two choices are deliberate
/// here, everything else stays at the Material 3 default.
class AppTheme {
  /// Blue is the one hue family that leaves amber, green, and red free for the
  /// three loan status colors, so a status chip never reads as brand color.
  static const Color seed = Color(0xFF24556E);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  /// Both brightnesses are built from the same seed, so the system dark mode is
  /// a working mode rather than an afterthought. No theme toggle is shipped,
  /// the app follows the phone setting.
  static ThemeData _build(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        ),
      );
}
