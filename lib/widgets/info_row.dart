import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';

/// Baris "label - nilai" untuk kartu info.
///
/// Dipakai di Detail Peminjaman dan sheet detail supaya tampilannya satu
/// sumber. Nilai kosong ditulis `-` alih-alih ruang kosong, jadi pembaca tahu
/// barisnya sengaja tidak diisi.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String? value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final text = (value == null || value!.isEmpty) ? '-' : value!;
    final valueStyle = AppText.style(size: 13, weight: 600, color: AppTheme.ink);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppTheme.chip))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.style(
                size: 13,
                weight: 500,
                color: AppTheme.muted,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(text, textAlign: TextAlign.right, style: valueStyle),
          ),
        ],
      ),
    );
  }
}
