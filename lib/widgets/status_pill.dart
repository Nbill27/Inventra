import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';

/// Badge kecil berisi ikon dan/atau teks, dipakai untuk status dan keterangan.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.dotColor,
    this.dot = false,
    this.upper = true,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppTheme.space10,
      vertical: AppTheme.space6,
    ),
  });

  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  /// Warna titik indikator — bila null memakai [foreground]. Dipakai agar titik
  /// tetap terang sementara teks memakai varian gelap.
  final Color? dotColor;

  /// Tampilkan titik di depan teks.
  final bool dot;

  /// Huruf besar + tracking lebar.
  final bool upper;

  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? AppTheme.onPrimary;
    final warnaTitik = dotColor ?? fg;
    final text = upper ? label.toUpperCase() : label;
    final style = upper
        ? AppText.upper(size: fontSize, weight: 600, color: fg)
        : AppText.style(size: fontSize, weight: 600, color: fg);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: warnaTitik,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppTheme.space6),
          ],
          if (icon != null) ...[
            Icon(icon, size: fontSize + 5, color: fg),
            const SizedBox(width: AppTheme.space6),
          ],
          // Flexible: label panjang turun baris, tidak melebar keluar layar.
          Flexible(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
