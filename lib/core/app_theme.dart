import 'package:flutter/material.dart';

import 'app_text.dart';

/// Tema aplikasi Inventra.
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
  //
  // Palet brand hanya empat warna: navy pekat `#000D60`, biru aksi `#001A97`,
  // lavender lembut `#DFE0FF`, dan putih `#FFFFFF`. Seluruh token lain adalah
  // turunan netral dari keempatnya, jadi mengganti satu nilai di sini ikut
  // mengubah semua layar.
  // ---------------------------------------------------------------------------

  /// Biru aksi (tombol, tautan, penanda terpilih, bilah kemajuan).
  static const Color blue = Color(0xFF001A97);

  /// Navy pekat untuk hero, bar bawah, FAB, dan teks utama.
  static const Color deep = Color(0xFF000D60);

  /// Lavender lembut untuk chip, kotak ikon, dan wadah aksen.
  static const Color lavender = Color(0xFFDFE0FF);

  static const Color primary = blue;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = lavender;
  static const Color onPrimaryContainer = blue;

  static const Color secondary = deep;
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = lavender;
  static const Color onSecondaryContainer = deep;
  static const Color secondaryFixed = lavender;

  static const Color tertiaryContainer = lavender;
  static const Color onTertiaryContainer = blue;

  static const Color error = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFDE7E7);
  static const Color onErrorContainer = Color(0xFF9F1D1D);

  // ---------------------------------------------------------------------------
  // Permukaan
  // ---------------------------------------------------------------------------

  static const Color surface = Color(0xFFF6F7FE);
  static const Color onSurface = deep;
  static const Color surfaceDim = Color(0xFFE6E7F6);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F2FC);
  static const Color surfaceContainer = Color(0xFFEBECF9);
  static const Color surfaceContainerHigh = Color(0xFFE3E4F7);
  static const Color surfaceContainerHighest = Color(0xFFCDCFEF);

  /// Teks sekunder di atas permukaan terang (kontras >= 4.5:1).
  static const Color onSurfaceVariant = Color(0xFF3F4470);

  /// Batas komponen yang harus terlihat — input, tombol outline, chip, checkbox.
  /// Kontras 3.6:1 di atas [surfaceContainerLow], lolos WCAG 1.4.11 (non-teks
  /// minimal 3:1).
  static const Color outline = Color(0xFF7E84AD);

  /// Pembatas dekoratif: garis pemisah, tepi kartu, panel. Sengaja tipis supaya
  /// tidak bersaing dengan isi, jadi tidak dituntut 3:1.
  static const Color outlineVariant = Color(0xFFE1E2F6);

  static const Color inverseSurface = deep;
  static const Color onInverseSurface = lavender;
  static const Color inversePrimary = lavender;

  // ---------------------------------------------------------------------------
  // Kartu & lapisan
  // ---------------------------------------------------------------------------

  /// Kartu solid putih di atas permukaan terang.
  static const Color cardSolid = surfaceContainerLowest;

  /// Bayangan halus bernuansa navy untuk kartu yang mengambang.
  static const Color cardShadow = Color(0x14000D60);

  /// Strip tipis aksen di kiri judul bagian.
  static const Color strip = blue;

  /// Teks utama / judul aplikasi.
  static const Color ink = deep;

  /// Teks sekunder (alias [onSurfaceVariant]).
  static const Color ink2 = onSurfaceVariant;

  /// Teks tersier / metadata.
  static const Color muted = Color(0xFF565C80);

  /// Chip ikon / pill latar terang.
  static const Color chip = lavender;

  /// Tautan / teks aksi di atas latar terang (>=4.5:1).
  static const Color link = blue;

  /// Isi kotak ikon beraksen pada kartu (lavender).
  static const Color iconBoxFill = lavender;

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
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          borderSide: const BorderSide(color: outline),
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
          side: const BorderSide(color: outline),
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
        side: const BorderSide(color: outline),
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
        shadowColor: const Color(0x33000D60),
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
        side: const BorderSide(color: outline, width: 1.5),
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
        selectionColor: Color(0x33001A97),
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
