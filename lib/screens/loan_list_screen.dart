import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../providers/loan_provider.dart';
import '../services/loan_export_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/status_chip.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';

/// FR-L5, FR-L6, and export: every loan with the borrower, the item, the dates,
/// and the derived status, newest first. The status filter accepts several
/// values at once, and no selection means every status.
class LoanListScreen extends StatelessWidget {
  const LoanListScreen({super.key});

  static const _exportService = LoanExportService();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peminjaman'),
        actions: [
          IconButton(
            tooltip: 'Ekspor riwayat',
            onPressed: provider.loans.isEmpty
                ? null
                : () => _export(context, provider.loans),
            icon: const Icon(Icons.file_download_outlined),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gap,
              0,
              AppTheme.gap,
              8,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _filters(context, provider),
            ),
          ),
        ),
      ),
      body: _body(context, provider),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Catat pinjam'),
      ),
    );
  }

  /// "Semua" clears the filter; the status chips toggle on and off, so several
  /// can be shown together.
  Widget _filters(BuildContext context, LoanProvider provider) {
    final selected = provider.statusFilters;
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Semua'),
          selected: selected.isEmpty,
          onSelected: (_) => context.read<LoanProvider>().filterBy(const {}),
        ),
        for (final status in LoanStatus.values)
          FilterChip(
            label: Text(_statusLabel(status)),
            selected: selected.contains(status),
            onSelected: (_) {
              final next = {...selected};
              if (!next.add(status)) {
                next.remove(status);
              }
              context.read<LoanProvider>().filterBy(next);
            },
          ),
      ],
    );
  }

  Widget _body(BuildContext context, LoanProvider provider) {
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
      if (provider.statusFilters.isNotEmpty) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Tidak ada peminjaman di filter ini',
          message: 'Pilih "Semua" untuk melihat seluruh riwayat peminjaman.',
          action: OutlinedButton(
            onPressed: () => context.read<LoanProvider>().filterBy(const {}),
            child: const Text('Lihat semua'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Belum ada peminjaman',
        message: 'Catat peminjaman pertama lewat tombol di bawah.',
        action: FilledButton.icon(
          onPressed: () => _openForm(context),
          icon: const Icon(Icons.add),
          label: const Text('Catat pinjam'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LoanProvider>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gap,
          8,
          AppTheme.gap,
          96,
        ),
        itemCount: loans.length,
        itemBuilder: (context, index) {
          final detail = loans[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LoanCard(
              key: ValueKey(detail.loan.id),
              detail: detail,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoanDetailScreen(detail: detail),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _statusLabel(LoanStatus status) => switch (status) {
        LoanStatus.borrowed => 'Dipinjam',
        LoanStatus.returned => 'Selesai',
      };

  /// Exports exactly what the list is showing, so the filter also decides what
  /// lands in the file.
  Future<void> _export(BuildContext context, List<LoanDetail> loans) async {
    final format = await showModalBottomSheet<LoanExportFormat>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Ekspor riwayat peminjaman'),
              subtitle: Text('${loans.length} peminjaman akan diekspor.'),
            ),
            const Divider(height: 1),
            for (final option in LoanExportFormat.values)
              ListTile(
                leading: Icon(
                  option == LoanExportFormat.excel
                      ? Icons.table_chart_outlined
                      : Icons.description_outlined,
                ),
                title: Text(option.label),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (format == null || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _exportService.build(loans: loans, format: format);
      final name =
          'riwayat-peminjaman-${formatDate(DateTime.now())}.${format.extension}';
      final saved = await _exportService.save(
        fileName: name,
        bytes: bytes,
        format: format,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Riwayat peminjaman disimpan.' : 'Ekspor dibatalkan.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengekspor riwayat: $error')),
      );
    }
  }

  void _openForm(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoanFormScreen()),
    );
  }
}

/// One loan as a card: who borrowed what, when it is due, and the status chip.
class _LoanCard extends StatelessWidget {
  const _LoanCard({super.key, required this.detail, required this.onTap});

  final LoanDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loan = detail.loan;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.borrowerName,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(loan: loan),
                ],
              ),
              const SizedBox(height: 8),
              _line(
                context,
                Icons.straighten,
                '${detail.item.name} · ${loan.quantity} unit',
              ),
              const SizedBox(height: 4),
              _line(
                context,
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

  Widget _line(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
