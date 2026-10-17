import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';

/// Tombol ikon bulat untuk bar judul (impor, ekspor, dan aksi sejenis).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppTheme.chip,
        shape: const CircleBorder(
          side: BorderSide(color: AppTheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: AppTheme.touch,
            height: AppTheme.touch,
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? AppTheme.outlineVariant
                  : AppTheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// Kolom cari bergaris tegas, dengan tombol bersihkan yang muncul saat terisi.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
    this.trailing,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  /// Aksi tambahan di ujung kanan kolom, mis. tombol pindai.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
        border: Border.all(color: AppTheme.chip, width: 2),
      ),
      padding: const EdgeInsets.only(
        left: AppTheme.spaceMd,
        right: AppTheme.space6,
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const Icon(Icons.search, size: 20, color: AppTheme.muted),
            const SizedBox(width: AppTheme.space10),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                style: AppText.style(
                  size: 13.5,
                  weight: 500,
                  color: AppTheme.ink,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: AppText.style(
                    size: 13.5,
                    weight: 500,
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return InkWell(
                  onTap: onClear,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: AppTheme.touch,
                    height: AppTheme.touch,
                    child: Icon(Icons.close, size: 18, color: AppTheme.muted),
                  ),
                );
              },
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Chip filter berbentuk pill: latar biru saat aktif, putih bergaris saat tidak.
///
/// Dipakai baris filter peminjaman supaya bentuknya sama dengan chip di layar
/// lain, bukan `FilterChip` bawaan yang tampil berbeda.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppTheme.primary : AppTheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        side: active
            ? BorderSide.none
            : const BorderSide(color: AppTheme.chip),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMd,
            vertical: AppTheme.spaceSm,
          ),
          child: Text(
            label,
            style: AppText.style(
              size: 12.5,
              weight: active ? 600 : 500,
              color: active ? AppTheme.onPrimary : AppTheme.ink,
            ),
          ),
        ),
      ),
    );
  }
}
