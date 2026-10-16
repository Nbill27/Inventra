import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../models/loan.dart';
import '../providers/loan_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/status_chip.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';

/// The three filter positions. `Semua` is not a [LoanStatus], so the filter is
/// its own type and only the selected value is translated for the provider.
enum _LoanFilter { all, borrowed, returned }

/// FR-L5 and FR-L6: every loan with the borrower, the item, the dates, and the
/// derived status, newest first.
class LoanListScreen extends StatelessWidget {
  const LoanListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final filter = _filterOf(provider.statusFilter);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peminjaman'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<_LoanFilter>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _LoanFilter.all, label: Text('Semua')),
                ButtonSegment(
                  value: _LoanFilter.borrowed,
                  label: Text('Dipinjam'),
                ),
                ButtonSegment(
                  value: _LoanFilter.returned,
                  label: Text('Selesai'),
                ),
              ],
              selected: {filter},
              onSelectionChanged: (selection) =>
                  context.read<LoanProvider>().filterBy(
                        _statusOf(selection.first),
                      ),
            ),
          ),
        ),
      ),
      body: _body(context, provider, filter),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Pinjam'),
      ),
    );
  }

  Widget _body(BuildContext context, LoanProvider provider, _LoanFilter filter) {
    final loans = provider.loans;

    if (provider.errorMessage != null && loans.isEmpty) {
      return ErrorState(
        message: provider.errorMessage!,
        onRetry: () => context.read<LoanProvider>().load(),
      );
    }

    if (loans.isEmpty) {
      if (provider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (filter != _LoanFilter.all) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Tidak ada peminjaman di filter ini',
          message: 'Pilih "Semua" untuk melihat seluruh riwayat peminjaman.',
          action: OutlinedButton(
            onPressed: () => context.read<LoanProvider>().filterBy(null),
            child: const Text('Lihat semua'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Belum ada peminjaman',
        message: 'Catat peminjaman pertama lewat tombol Pinjam di bawah.',
        action: FilledButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Pinjam barang'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LoanProvider>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: loans.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final detail = loans[index];
          return ListTile(
            isThreeLine: true,
            title: Text(detail.loan.borrowerName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${detail.item.name} - ${detail.loan.quantity} unit'),
                Text(
                  'Pinjam ${formatDisplayDate(detail.loan.loanDate)} | '
                  'Kembali ${formatDisplayDate(detail.loan.dueDate)}',
                ),
              ],
            ),
            trailing: StatusChip(loan: detail.loan),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LoanDetailScreen(detail: detail),
              ),
            ),
          );
        },
      ),
    );
  }

  static _LoanFilter _filterOf(LoanStatus? status) => switch (status) {
        null => _LoanFilter.all,
        LoanStatus.borrowed => _LoanFilter.borrowed,
        LoanStatus.returned => _LoanFilter.returned,
      };

  static LoanStatus? _statusOf(_LoanFilter filter) => switch (filter) {
        _LoanFilter.all => null,
        _LoanFilter.borrowed => LoanStatus.borrowed,
        _LoanFilter.returned => LoanStatus.returned,
      };

  void _openForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoanFormScreen()),
    );
  }
}
