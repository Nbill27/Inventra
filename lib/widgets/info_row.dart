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
    required this.nilai,
    this.garisBawah = true,
    this.nilaiRataKanan = true,
  });

  final String label;
  final String? nilai;
  final bool garisBawah;

  /// Nilai rata kanan (gaya detail) atau rata kiri (gaya sheet).
  final bool nilaiRataKanan;

  @override
  Widget build(BuildContext context) {
    final teks = (nilai == null || nilai!.isEmpty) ? '-' : nilai!;
    final gayaNilai = AppText.style(size: 13, weight: 600, color: AppTheme.ink);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space12),
      decoration: BoxDecoration(
        border: garisBawah
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
          if (nilaiRataKanan)
            Expanded(
              child: Text(teks, textAlign: TextAlign.right, style: gayaNilai),
            )
          else
            Text(teks, style: gayaNilai),
        ],
      ),
    );
  }
}
