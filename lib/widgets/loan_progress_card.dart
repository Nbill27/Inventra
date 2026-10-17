import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/item.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import 'panel.dart';
import 'status_chip.dart';

/// Kartu barang yang dipinjam: identitas barang, status, dan sejauh mana masa
/// pinjamnya sudah berjalan.
///
/// Dipakai layar Detail Peminjaman sebagai ringkasan visual, jadi angka yang
/// ditampilkan semuanya diturunkan dari tanggal pinjam dan rencana kembali —
/// tidak ada yang disimpan di database.
class LoanProgressCard extends StatelessWidget {
  const LoanProgressCard({super.key, required this.detail, this.today});

  final LoanDetail detail;

  /// Bisa diisi supaya test bisa mematok hari saat kartu dirender.
  final DateTime? today;

  /// Jumlah kotak di bilah kemajuan.
  static const _segments = 6;

  @override
  Widget build(BuildContext context) {
    final loan = detail.loan;
    final item = detail.item;
    final todayOnly = dateOnly(today ?? DateTime.now());
    final isReturned = loan.status == LoanStatus.returned;

    // Dihitung inklusif: pinjam dan kembali di hari yang sama berarti 1 hari.
    final totalDays = loan.dueDate.difference(loan.loanDate).inDays + 1;
    final daysLeft = loan.dueDate.difference(todayOnly).inDays;
    final filledSegments = isReturned || totalDays <= 0
        ? _segments.toDouble()
        : (totalDays - daysLeft) / totalDays * _segments;

    final (String remainingLabel, Color remainingColor) = _remaining(
      loan,
      daysLeft,
    );
    final subtitle = _subtitle(item);

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.iconBoxFill,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.straighten,
                  size: 20,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: AppText.style(
                        size: 15,
                        weight: 700,
                        color: AppTheme.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        subtitle,
                        style: AppText.style(
                          size: 12,
                          weight: 500,
                          color: AppTheme.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              StatusChip(loan: loan, today: today),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _SegmentedBar(filled: filledSegments, total: _segments),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: Text(
                  remainingLabel,
                  style: AppText.style(
                    size: 13,
                    weight: 700,
                    color: remainingColor,
                  ),
                ),
              ),
              Text(
                '${formatShortDate(loan.loanDate)} → '
                '${formatShortDate(loan.dueDate)}',
                style: AppText.style(
                  size: 12,
                  weight: 500,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Sisa waktu dalam kata-kata, beserta warnanya. Peminjaman yang sudah
  /// selesai menampilkan tanggal kembalinya, bukan "Selesai" lagi, karena
  /// badge status di kanan atas sudah mengatakannya.
  static (String, Color) _remaining(Loan loan, int daysLeft) {
    if (loan.status == LoanStatus.returned) {
      final returnDate = loan.returnDate;
      return (
        returnDate == null
            ? 'Sudah dikembalikan'
            : 'Dikembalikan ${formatShortDate(returnDate)}',
        AppTheme.ok,
      );
    }
    if (daysLeft < 0) {
      // Chip status di baris atas sudah menulis "Terlambat N hari", jadi baris
      // sisa waktu memakai kata lain supaya tidak kembar.
      return ('Lewat ${-daysLeft} hari', AppTheme.danger);
    }
    if (daysLeft == 0) {
      return ('Kembali hari ini', AppTheme.warn);
    }
    return ('$daysLeft hari lagi', AppTheme.link);
  }

  /// Kode barang digandeng merek; salah satu kosong tetap tampil sendiri.
  static String? _subtitle(Item item) {
    final parts = [item.code, item.brand]
        .whereType<String>()
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Bilah kemajuan bersegmen, bukan satu batang penuh, supaya porsi yang
/// berjalan bisa dibaca tanpa mengukur panjang persisnya.
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({required this.filled, required this.total});

  /// Porsi terisi dalam satuan segmen; boleh pecahan.
  final double filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final filledCount = filled.round().clamp(0, total);
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.space6),
          Expanded(
            child: Container(
              height: 7,
              decoration: BoxDecoration(
                color: i < filledCount
                    ? AppTheme.primary
                    : AppTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
