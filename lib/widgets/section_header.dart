import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';

/// Judul bagian dengan aksen strip biru dan aksi opsional di sebelah kanan.
///
/// Gaya datar (tanpa kartu): teks dengan strip aksen di kiri, supaya hierarki
/// bagian tegas tanpa latar tambahan.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailingLabel,
    this.trailingIcon,
    this.onTrailingTap,
    this.trailing,
  });

  final String title;
  final String? trailingLabel;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppTheme.strip,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              title,
              style: AppText.headlineSm.copyWith(color: AppTheme.ink),
            ),
          ),
          if (trailing != null)
            trailing!
          else if (trailingLabel != null || trailingIcon != null)
            TextButton(
              onPressed: onTrailingTap,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(AppTheme.space6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    trailingLabel ?? '',
                    style: AppText.labelMd.copyWith(
                      color: AppTheme.link,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: AppTheme.space2),
                    Icon(trailingIcon, size: 18, color: AppTheme.link),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Judul kecil di atas kelompok input di dalam panel.
///
/// Dipakai form supaya setiap kelompok bidang punya label yang sama bentuknya
/// dengan layar lain, tanpa ikut memakai strip [SectionHeader].
class GroupLabel extends StatelessWidget {
  const GroupLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primary),
        const SizedBox(width: AppTheme.spaceSm),
        Text(
          label.toUpperCase(),
          style: AppText.upper(
            size: 10,
            weight: 700,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
