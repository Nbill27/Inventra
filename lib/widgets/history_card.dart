import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import 'status_pill.dart';

/// Kartu satu baris riwayat: barang, peminjam, status, durasi, tanggal, dan
/// catatan pengembalian bila ada.
///
/// Berbeda dari [LoanCard] yang ringkas untuk daftar aktif, kartu ini memuat
/// keterangan lengkap karena dipakai di layar arsip.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    super.key,
    required this.detail,
    required this.onTap,
    this.today,
  });

  final LoanDetail detail;
  final VoidCallback onTap;

  /// Bisa diisi supaya test bisa mematok hari saat status dihitung.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final loan = detail.loan;
    final now = today ?? DateTime.now();
    final status = _status(loan, now);
    final durationDays = _durationDays(loan, now);
    final note = loan.note?.trim() ?? '';

    return Material(
      color: AppTheme.cardSolid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        side: const BorderSide(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.item.name,
                          style: AppText.style(
                            size: 15,
                            weight: 700,
                            color: AppTheme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppTheme.spaceXs),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline,
                              size: 15,
                              color: AppTheme.muted,
                            ),
                            const SizedBox(width: AppTheme.spaceXs),
                            Expanded(
                              child: Text(
                                loan.borrowerName,
                                style: AppText.style(
                                  size: 13,
                                  weight: 500,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  StatusPill(
                    label: status.label,
                    upper: false,
                    dot: true,
                    fontSize: 11,
                    background: status.background,
                    foreground: status.foreground,
                    dotColor: status.foreground,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space10,
                      vertical: AppTheme.spaceXs,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Wrap(
                spacing: AppTheme.spaceXs,
                runSpacing: AppTheme.spaceXs,
                children: [
                  _Badge(
                    icon: Icons.schedule,
                    label: 'Durasi: $durationDays hari',
                  ),
                  _Badge(
                    icon: Icons.event_available_outlined,
                    label: loan.returnDate == null
                        ? 'Tenggat: ${formatDisplayDate(loan.dueDate)}'
                        : 'Kembali: ${formatDisplayDate(loan.returnDate!)}',
                  ),
                ],
              ),
              if (note.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.space10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.notes,
                        size: 16,
                        color: AppTheme.outline,
                      ),
                      const SizedBox(width: AppTheme.spaceXs),
                      Expanded(
                        child: Text(
                          note,
                          style: AppText.bodySm.copyWith(
                            color: AppTheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ref ID: #TRX-${loan.id ?? '-'}',
                      style: AppText.style(
                        size: 11,
                        weight: 500,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                  Text(
                    'Lihat detail',
                    style: AppText.style(
                      size: 12,
                      weight: 600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppTheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Label dan warna status. Peminjaman selesai bisa "Tepat Waktu" atau
  /// "Terlambat N hari"; yang masih berjalan memakai tenggat sebagai patokan.
  ({String label, Color background, Color foreground}) _status(
    Loan loan,
    DateTime today,
  ) {
    if (loan.status == LoanStatus.returned) {
      final returnDate = loan.returnDate;
      if (returnDate != null && isBeforeDay(loan.dueDate, returnDate)) {
        final days = dateOnly(returnDate)
            .difference(dateOnly(loan.dueDate))
            .inDays;
        return (
          label: 'Terlambat $days hari',
          background: AppTheme.dangerSoft,
          foreground: AppTheme.danger,
        );
      }
      return (
        label: 'Tepat Waktu',
        background: AppTheme.okSoft,
        foreground: AppTheme.ok,
      );
    }

    if (loan.isLateOn(today)) {
      return (
        label: 'Terlambat ${loan.daysLateOn(today)} hari',
        background: AppTheme.dangerSoft,
        foreground: AppTheme.danger,
      );
    }

    return (
      label: 'Dipinjam',
      background: AppTheme.chip,
      foreground: AppTheme.primary,
    );
  }

  /// Lama pinjam dalam hari; peminjaman yang belum kembali dihitung sampai hari
  /// ini. Minimal satu hari supaya pinjam-kembali di hari yang sama tetap wajar.
  int _durationDays(Loan loan, DateTime today) {
    final end = loan.returnDate ?? today;
    final days = dateOnly(end).difference(dateOnly(loan.loanDate)).inDays;
    return days < 1 ? 1 : days;
  }
}

/// Keterangan kecil berlatar lembut di dalam kartu.
class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.spaceXs),
          Text(
            label,
            style: AppText.style(
              size: 11,
              weight: 500,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
