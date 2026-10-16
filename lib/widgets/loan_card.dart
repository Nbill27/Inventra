import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/loan_detail.dart';
import 'status_chip.dart';

/// Satu peminjaman sebagai kartu: siapa meminjam apa, sampai kapan, dan status.
///
/// Dipakai daftar Peminjaman dan beranda, supaya keduanya menampilkan bentuk
/// yang sama untuk data yang sama.
class LoanCard extends StatelessWidget {
  const LoanCard({super.key, required this.detail, required this.onTap});

  final LoanDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loan = detail.loan;

    return Card(
      color: AppTheme.cardSolid,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        side: const BorderSide(color: AppTheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.borrowerName,
                      style: AppText.style(
                        size: 14,
                        weight: 600,
                        color: AppTheme.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  StatusChip(loan: loan),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              _line(
                Icons.straighten,
                '${detail.item.name} · ${loan.quantity} unit',
              ),
              const SizedBox(height: AppTheme.spaceXs),
              _line(
                Icons.event_outlined,
                '${formatDisplayDate(loan.loanDate)} → '
                    '${formatDisplayDate(loan.dueDate)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.muted),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: Text(
            text,
            style: AppText.style(
              size: 12.5,
              weight: 500,
              color: AppTheme.muted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
