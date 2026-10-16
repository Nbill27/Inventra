import 'package:flutter/material.dart';

import 'app_text.dart';

/// Tema aplikasi Peminjaman Barang.
///
/// Palet mengikuti arah visual `barcode_warehouse`: biru `#0878F9` (brand) di
/// atas **latar terang solid** — tanpa gradien global dan tanpa kaca wajib,
/// supaya hierarki tegas dan kontras terjaga. Kartu solid putih + border halus.
///
/// Token di kelas ini satu-satunya sumber warna dan jarak. Layar tidak boleh
/// menulis nilai warna langsung supaya kedua hal berikut tetap berlaku:
///
/// * Biru adalah satu-satunya warna brand, sehingga hijau/kuning/merah tetap
///   bebas dipakai sebagai warna status peminjaman.
/// * Semua kontrol yang bisa disentuh minimal 44 dp, di atas ambang Material.
class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Warna inti
  // ---------------------------------------------------------------------------

  /// Biru utama (aksi, tautan, nav).
  static const Color blue = Color(0xFF0878F9);

  /// Biru pekat untuk hero, bar bawah, dan FAB.
  static const Color deep = Color(0xFF063E91);

  static const Color primary = blue;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFDCEBFF);
  static const Color onPrimaryContainer = Color(0xFF0B3A75);

  static const Color secondary = deep;
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFE2EAF6);
  static const Color onSecondaryContainer = Color(0xFF10285E);
  static const Color secondaryFixed = Color(0xFFD6E2F2);

  static const Color tertiaryContainer = Color(0xFFE3F2FA);
  static const Color onTertiaryContainer = Color(0xFF0B3A75);

  static const Color error = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFDE7E7);
  static const Color onErrorContainer = Color(0xFF9F1D1D);

  // ---------------------------------------------------------------------------
  // Permukaan
  // ---------------------------------------------------------------------------

  static const Color surface = Color(0xFFF6F8FB);
  static const Color onSurface = Color(0xFF14213D);
  static const Color surfaceDim = Color(0xFFE6EBF2);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F3F8);
  static const Color surfaceContainer = Color(0xFFE9EEF5);
  static const Color surfaceContainerHigh = Color(0xFFDEE5EF);
  static const Color surfaceContainerHighest = Color(0xFFCBD6E4);

  /// Teks sekunder di atas permukaan terang (kontras >= 4.5:1).
  static const Color onSurfaceVariant = Color(0xFF4A5A75);

  static const Color outline = Color(0xFFB9C6D8);
  static const Color outlineVariant = Color(0xFFDDE4EE);

  static const Color inverseSurface = deep;
  static const Color onInverseSurface = Color(0xFFE3ECF8);
  static const Color inversePrimary = Color(0xFF9CCBFF);

  // ---------------------------------------------------------------------------
  // Kartu & lapisan
  // ---------------------------------------------------------------------------

  /// Kartu solid putih di atas permukaan terang.
  static const Color cardSolid = Color(0xFFFFFFFF);

  /// Bayangan halus netral untuk kartu yang mengambang.
  static const Color cardShadow = Color(0x1414230F);

  /// Strip tipis aksen di kiri judul bagian.
  static const Color strip = blue;

  /// Latar kartu biasa (kompatibel nama lama) — putih.
  static const Color card = Color(0xFFFFFFFF);

  /// Aksen (kompatibel) — biru utama.
  static const Color accent = blue;

  /// Teks utama / judul aplikasi.
  static const Color ink = Color(0xFF14213D);

  /// Teks sekunder.
  static const Color ink2 = Color(0xFF4A5A75);

  /// Teks tersier / metadata.
  static const Color muted = Color(0xFF5C6B85);

  /// Chip ikon / pill latar terang.
  static const Color chip = Color(0xFFE2EAF6);

  /// Tautan / teks aksi di atas latar terang (>=4.5:1).
  static const Color link = Color(0xFF0A4FA8);

  static const Color bad = Color(0xFFDC2626);
  static const Color badText = Color(0xFF9F1D1D);

  /// Lapisan gelap transparan saat memuat.
  static const Color scrim = Color(0x5914213D);

  /// Isi kotak ikon beraksen pada kartu (biru muda).
  static const Color iconBoxFill = Color(0xFFDCEBFF);

  // ---------------------------------------------------------------------------
  // Warna status peminjaman
  //
  // Dipisah dari warna brand supaya "Selesai", "Dipinjam", dan "Terlambat"
  // tetap terbaca berbeda tanpa bergantung pada warna brand. Setiap pasangan
  // latar/teks sudah di atas 4.5:1.
  // ---------------------------------------------------------------------------

  static const Color ok = Color(0xFF0E7C5A);
  static const Color okSoft = Color(0xFFE2F4EC);
  static const Color warn = Color(0xFF8A5606);
  static const Color warnSoft = Color(0xFFFBF0DC);
  static const Color danger = Color(0xFFBE2B2B);
  static const Color dangerSoft = Color(0xFFFBE7E7);

  // ---------------------------------------------------------------------------
  // Bentuk & jarak
  // ---------------------------------------------------------------------------

  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 14;
  static const double radiusXl = 20;

  /// Radius kartu pendek dan baris daftar.
  static const double radiusCard = 22;

  /// Radius kartu utama.
  static const double radiusPanel = 24;

  /// Radius sheet dan dialog.
  static const double radiusSheet = 26;

  /// Radius penuh (pill).
  static const double radiusPill = 999;

  static const double space2 = 2;
  static const double spaceXs = 4;
  static const double space6 = 6;
  static const double spaceSm = 8;
  static const double space10 = 10;
  static const double space12 = 12;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double spaceXl = 36;

  /// Target sentuh minimum.
  static const double touch = 44;

  /// Ruang bawah untuk bar aksi yang mengambang atau FAB.
  static const double spaceBottomBar = 88;

  /// Padding layar standar.
  static const EdgeInsets margin = EdgeInsets.symmetric(horizontal: spaceMd);

  /// Jarak antar bagian di dalam satu layar.
  static const double gap = spaceMd;

  // ---------------------------------------------------------------------------
  // ColorScheme
  // ---------------------------------------------------------------------------

  static const ColorScheme scheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    primaryContainer: primaryContainer,
    onPrimaryContainer: onPrimaryContainer,
    secondary: secondary,
    onSecondary: onSecondary,
    secondaryContainer: secondaryContainer,
    onSecondaryContainer: onSecondaryContainer,
    tertiary: blue,
    onTertiary: onTertiaryContainer,
    tertiaryContainer: tertiaryContainer,
    onTertiaryContainer: onTertiaryContainer,
    error: error,
    onError: onError,
    errorContainer: errorContainer,
    onErrorContainer: onErrorContainer,
    surface: surface,
    onSurface: onSurface,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    onSurfaceVariant: onSurfaceVariant,
    outline: outline,
    outlineVariant: outlineVariant,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    surfaceTint: primary,
  );

  // ---------------------------------------------------------------------------
  // TextTheme
  // ---------------------------------------------------------------------------

  static final TextTheme textTheme = const TextTheme(
    headlineLarge: AppText.headlineLg,
    headlineMedium: AppText.headlineMd,
    headlineSmall: AppText.headlineSm,
    titleLarge: AppText.headlineSm,
    titleMedium: TextStyle(
      fontFamily: AppText.family,
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    titleSmall: TextStyle(
      fontFamily: AppText.family,
      fontSize: 14,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: AppText.bodyLg,
    bodyMedium: AppText.bodyMd,
    bodySmall: AppText.bodySm,
    labelLarge: AppText.labelLg,
    labelMedium: AppText.labelMd,
    labelSmall: AppText.labelSm,
  ).apply(bodyColor: onSurface, displayColor: onSurface);

  // ---------------------------------------------------------------------------
  // ThemeData
  // ---------------------------------------------------------------------------

  /// Tema terang. Latar global digambar oleh `AppBackground` lewat
  /// `MaterialApp.builder`, jadi scaffold sendiri dibiarkan transparan.
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: AppText.family,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarThemeData(
        backgroundColor: surfaceBright,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.headlineSm.copyWith(color: onSurface),
        iconTheme: const IconThemeData(color: onSurfaceVariant, size: 24),
      ),

      cardTheme: CardThemeData(
        color: cardSolid,
        surfaceTintColor: Colors.transparent,
        shadowColor: cardShadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPanel),
          side: const BorderSide(color: outlineVariant),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 1,
      ),

      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: 14,
        ),
        hintStyle: AppText.bodyMd.copyWith(color: onSurfaceVariant),
        labelStyle: AppText.bodyMd.copyWith(color: onSurfaceVariant),
        floatingLabelStyle: AppText.labelMd.copyWith(color: primary),
        errorStyle: AppText.bodySm.copyWith(color: error),
        prefixIconColor: onSurfaceVariant,
        suffixIconColor: onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),

      // Tombol besar agar mudah ditekan.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          disabledBackgroundColor: surfaceContainerHigh,
          disabledForegroundColor: ink2,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: spaceLg),
          textStyle: AppText.labelLg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusXl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          // Teks outline duduk di atas latar terang: `primary` hanya ~2.8:1.
          foregroundColor: link,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: spaceLg),
          textStyle: AppText.labelLg,
          side: const BorderSide(color: outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusXl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: link,
          textStyle: AppText.labelMd,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: onSurfaceVariant),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLow,
        selectedColor: cardSolid,
        disabledColor: surfaceContainerLow,
        side: const BorderSide(color: outlineVariant),
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: AppText.labelMd.copyWith(color: onSurfaceVariant),
        secondaryLabelStyle: AppText.labelMd.copyWith(color: onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: space12,
          vertical: spaceSm,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        // Biru gelap agar bar terasa kokoh; label terpilih putih dan yang
        // tidak terpilih memakai chip terang — keduanya kontras di atas biru.
        backgroundColor: deep,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.white,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final terpilih = states.contains(WidgetState.selected);
          return AppText.labelSm.copyWith(
            color: terpilih ? Colors.white : chip,
            fontWeight: terpilih ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final terpilih = states.contains(WidgetState.selected);
          return IconThemeData(size: 24, color: terpilih ? primary : chip);
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inverseSurface,
        contentTextStyle: AppText.bodyMd.copyWith(color: onInverseSurface),
        actionTextColor: secondaryFixed,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
        insetPadding: const EdgeInsets.fromLTRB(
          spaceMd,
          spaceSm,
          spaceMd,
          spaceMd,
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xF2FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: const Color(0x3310285E),
        titleTextStyle: AppText.headlineSm.copyWith(color: onSurface),
        contentTextStyle: AppText.bodyMd.copyWith(color: onSurfaceVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSheet),
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xF2FFFFFF),
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusSheet),
          ),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        side: const BorderSide(color: outlineVariant, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(onPrimary),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceVariant,
        textColor: onSurface,
        titleTextStyle: AppText.bodyLg.copyWith(
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        subtitleTextStyle: AppText.bodySm.copyWith(color: onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceXs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // Biru gelap agar konsisten dengan bar bawah.
        backgroundColor: deep,
        foregroundColor: onPrimary,
        elevation: 2,
        extendedTextStyle: AppText.labelLg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: surfaceContainerHigh,
      ),

      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: blue,
        selectionColor: Color(0x330878F9),
        selectionHandleColor: blue,
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: inverseSurface,
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        textStyle: AppText.bodySm.copyWith(color: onInverseSurface),
      ),
    );
  }
}
