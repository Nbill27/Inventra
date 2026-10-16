import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../providers/loan_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/status_chip.dart';
import 'loan_form_screen.dart';

/// FR-L7: every field of one loan, plus the actions that change its state.
///
/// After a change this screen closes instead of redrawing, because the row it
/// was opened with is a snapshot: the list behind is reloaded by the provider
/// and shows the current values.
class LoanDetailScreen extends StatefulWidget {
  const LoanDetailScreen({super.key, required this.detail});

  final LoanDetail detail;

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  bool _busy = false;

  Future<void> _markReturned() async {
    final loan = widget.detail.loan;
    final id = loan.id;
    if (id == null) {
      return;
    }

    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: isBeforeDay(today, loan.loanDate) ? loan.loanDate : today,
      firstDate: loan.loanDate,
      lastDate: DateTime(2100),
      helpText: 'Tanggal barang dikembalikan',
    );
    if (picked == null || !mounted) {
      return;
    }

    final provider = context.read<LoanProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    final error = await provider.markReturned(loanId: id, returnDate: picked);

    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Peminjaman selesai, stok sudah dikembalikan.'),
      ),
    );
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanFormScreen(loan: widget.detail.loan),
      ),
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final loan = widget.detail.loan;
    final id = loan.id;
    if (id == null) {
      return;
    }

    final returnsStock = loan.status == LoanStatus.borrowed;
    final confirmed = await confirmAction(
      context,
      title: 'Hapus peminjaman?',
      message: returnsStock
          ? 'Peminjaman ${loan.borrowerName} akan dihapus dan '
              '${loan.quantity} unit ${widget.detail.item.name} kembali ke stok.'
          : 'Peminjaman ${loan.borrowerName} akan dihapus dari riwayat. Stok '
              'tidak berubah karena barangnya sudah dikembalikan.',
      confirmLabel: 'Hapus',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final provider = context.read<LoanProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    final error = await provider.delete(id);

    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Peminjaman dihapus.')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final loan = widget.detail.loan;
    final item = widget.detail.item;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Peminjaman')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gap,
          AppTheme.gap,
          AppTheme.gap,
          32,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          loan.borrowerName,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusChip(loan: loan),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(color: scheme.outlineVariant, height: 1),
                  const SizedBox(height: 12),
                  _row(
                    Icons.straighten,
                    'Barang',
                    _itemLabel(item.name, item.code),
                  ),
                  _row(Icons.numbers, 'Jumlah', '${loan.quantity} unit'),
                  _row(
                    Icons.phone_outlined,
                    'Kontak',
                    loan.contact ?? 'Tidak diisi',
                  ),
                  _row(
                    Icons.event_outlined,
                    'Tanggal pinjam',
                    formatLongDate(loan.loanDate),
                  ),
                  _row(
                    Icons.event_available_outlined,
                    'Rencana kembali',
                    formatLongDate(loan.dueDate),
                  ),
                  if (loan.returnDate != null)
                    _row(
                      Icons.assignment_turned_in_outlined,
                      'Dikembalikan',
                      formatLongDate(loan.returnDate!),
                    ),
                  _row(Icons.notes_outlined, 'Catatan', loan.note ?? 'Tidak ada'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (loan.status == LoanStatus.borrowed) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _markReturned,
              icon: const Icon(Icons.assignment_turned_in_outlined),
              label: const Text('Tandai dikembalikan'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _busy ? null : _edit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Ubah'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  static String _itemLabel(String name, String? code) =>
      code == null ? name : '$name ($code)';

  /// One labelled fact: a leading icon keeps the column scannable, and the
  /// label sits above the value so long values never squeeze the label away.
  Widget _row(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
