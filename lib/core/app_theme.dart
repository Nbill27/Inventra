import 'package:flutter/material.dart';

/// The app's Material 3 theme.
///
/// Every screen leans on this instead of styling its own widgets, so spacing,
/// corners, and control heights stay identical everywhere. Two decisions are
/// deliberate:
///
/// * Blue is the one hue family that leaves amber, green, and red free for the
///   three loan status colours, so a status chip never reads as brand colour.
/// * Every tappable control is at least [touch] tall, which keeps the whole app
///   above Material's 48dp touch-target minimum.
class AppTheme {
  static const Color seed = Color(0xFF24556E);

  /// Corner radii. [radius] is for surfaces (cards, dialogs), [radiusSm] for
  /// controls (buttons, inputs, chips).
  static const double radius = 16;
  static const double radiusSm = 12;

  /// Minimum height for anything tappable.
  static const double touch = 48;

  /// Gap between stacked form fields and cards.
  static const double gap = 16;

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  /// Both brightnesses are built from the same seed, so the system dark mode is
  /// a working mode rather than an afterthought. No theme toggle is shipped,
  /// the app follows the phone setting.
  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    final surfaceShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusSm),
    );
    final controlBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: BorderSide(color: scheme.primary, width: 2),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: BorderSide(color: scheme.error),
    );
    const buttonText = TextStyle(fontWeight: FontWeight.w600);

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,

      appBarTheme: AppBarThemeData(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      // A flat card with a hairline outline: the list rows read as one calm
      // surface family instead of a stack of drop shadows.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: surfaceShape.copyWith(
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),

      // Filled inputs make an empty field visible in both brightnesses, which a
      // pure outline does not.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: controlBorder,
        enabledBorder: controlBorder,
        focusedBorder: focusedBorder,
        errorBorder: errorBorder,
        focusedErrorBorder: focusedBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        helperStyle: TextStyle(color: scheme.onSurfaceVariant),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, touch),
          shape: controlShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, touch),
          shape: controlShape,
          foregroundColor: scheme.primary,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, touch),
          shape: controlShape,
          foregroundColor: scheme.primary,
          textStyle: buttonText,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: surfaceShape,
        extendedTextStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),

      chipTheme: ChipThemeData(
        shape: controlShape,
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      // Floating snackbars read as a transient message instead of a bar welded
      // to the bottom edge.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),

      dialogTheme: DialogThemeData(shape: surfaceShape),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
    );
  }
}
