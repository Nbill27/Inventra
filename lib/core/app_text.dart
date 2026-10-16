import 'package:flutter/material.dart';

/// Skala teks aplikasi — satu font untuk semua halaman: **Poppins**.
///
/// Poppins di sini font **statis** (bukan variable font), jadi bobot diatur
/// lewat [TextStyle.fontWeight]; `fontVariations` sengaja tidak dipakai.
abstract final class AppText {
  static const String family = 'Poppins';

  // --- Headline ---
  static const TextStyle headlineLg = TextStyle(
    fontFamily: family,
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );
  static const TextStyle headlineMd = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.27,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );
  static const TextStyle headlineSm = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.33,
    fontWeight: FontWeight.w600,
  );

  // --- Body ---
  static const TextStyle bodyLg = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodyMd = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w400,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.33,
    fontWeight: FontWeight.w400,
  );

  // --- Label ---
  static const TextStyle labelLg = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.33,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );
  static const TextStyle labelMd = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.38,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.13,
  );
  static const TextStyle labelSm = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.27,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.33,
  );

  /// Teks dengan ukuran/bobot bebas.
  static TextStyle style({
    double size = 12,
    int weight = 500,
    double? letterSpacing,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: 1.3,
      fontWeight: _weight(weight),
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Label huruf besar dengan tracking lebar — dipakai untuk judul bagian
  /// kecil dan badge.
  static TextStyle upper({
    double size = 11,
    int weight = 600,
    Color? color,
  }) {
    return style(
      size: size,
      weight: weight,
      letterSpacing: size * 0.05,
      color: color,
    );
  }

  static FontWeight _weight(int w) {
    return switch (w) {
      <= 100 => FontWeight.w100,
      <= 200 => FontWeight.w200,
      <= 300 => FontWeight.w300,
      <= 400 => FontWeight.w400,
      <= 500 => FontWeight.w500,
      <= 600 => FontWeight.w600,
      <= 700 => FontWeight.w700,
      <= 800 => FontWeight.w800,
      _ => FontWeight.w900,
    };
  }
}
