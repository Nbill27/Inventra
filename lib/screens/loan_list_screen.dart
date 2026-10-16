import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../providers/loan_provider.dart';
import '../services/loan_export_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_chrome.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/status_chip.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';

/// FR-L5, FR-L6, dan ekspor: setiap peminjaman beserta peminjam, barang,
/// tanggal, dan status turunannya, terbaru lebih dulu. Filter status menerima
/// beberapa nilai sekaligus, dan tanpa pilihan berarti semua status.
class LoanListScreen extends StatelessWidget {
  const LoanListScreen({super.key});

  static const _exportService = LoanExportService();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loans = provider.loans;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 66,
        titleSpacing: AppTheme.spaceMd,
        automaticallyImplyLeading: false,
        flexibleSpace: appBarScrim(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Peminjaman',
              style: AppText.style(size: 20, weight: 700, color: AppTheme.ink),
            ),
            Text(
              provider.isLoading && loans.isEmpty
                  ? 'Memuat…'
                  : '${loans.length} peminjaman',
              style: AppText.style(
                size: 12,
                weight: 500,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          RoundIconButton(
            tooltip: 'Ekspor riwayat',
            icon: Icons.ios_share,
            onTap: loans.isEmpty ? null : () => _export(context, loans),
          ),
          const SizedBox(width: AppTheme.spaceSm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Catat pinjam'),
      ),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                AppTheme.spaceSm,
                AppTheme.spaceMd,
                AppTheme.spaceSm,
              ),
              child: SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _filters(context, provider),
                ),
              ),
            ),
            Expanded(child: _body(context, provider)),
          ],
        ),
      ),
    );
  }

  /// "Semua" mengosongkan filter; chip status menyala-mati, jadi beberapa
  /// status bisa tampil bersamaan.
  List<Widget> _filters(BuildContext context, LoanProvider provider) {
    final selected = provider.statusFilters;
    return [
      Padding(
        padding: const EdgeInsets.only(right: AppTheme.spaceSm),
        child: FilterPill(
          label: 'Semua',
          aktif: selected.isEmpty,
          onTap: () => context.read<LoanProvider>().filterBy(const {}),
        ),
      ),
      for (final status in LoanStatus.values)
        Padding(
          padding: const EdgeInsets.only(right: AppTheme.spaceSm),
          child: FilterPill(
            label: _statusLabel(status),
            aktif: selected.contains(status),
            onTap: () {
              final next = {...selected};
              if (!next.add(status)) {
                next.remove(status);
              }
              context.read<LoanProvider>().filterBy(next);
            },
          ),
        ),
    ];
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
          actions: [
            OutlinedButton(
              onPressed: () => context.read<LoanProvider>().filterBy(const {}),
              child: const Text('Lihat semua'),
            ),
          ],
        );
      }
      return EmptyState(
        icon: Icons.assignment_outlined,
        title: 'Belum ada peminjaman',
        message: 'Catat peminjaman pertama lewat tombol di bawah.',
        actions: [
          FilledButton.icon(
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Catat pinjam'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LoanProvider>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMd,
          0,
          AppTheme.spaceMd,
          AppTheme.spaceBottomBar,
        ),
        itemCount: loans.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space10),
        itemBuilder: (context, index) {
          final detail = loans[index];
          return _LoanCard(
            key: ValueKey(detail.loan.id),
            detail: detail,
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

  static String _statusLabel(LoanStatus status) => switch (status) {
        LoanStatus.borrowed => 'Dipinjam',
        LoanStatus.returned => 'Selesai',
      };

  /// Mengekspor persis apa yang sedang tampil, jadi filter juga menentukan isi
  /// berkasnya.
  Future<void> _export(BuildContext context, List<LoanDetail> loans) async {
    final format = await showModalBottomSheet<LoanExportFormat>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                0,
                AppTheme.spaceMd,
                AppTheme.spaceSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ekspor riwayat peminjaman',
                    style: AppText.headlineSm.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: AppTheme.space2),
                  Text(
                    '${loans.length} peminjaman akan diekspor.',
                    style: AppText.bodySm.copyWith(
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final option in LoanExportFormat.values)
              ListTile(
                leading: Icon(
                  option == LoanExportFormat.excel
                      ? Icons.grid_on
                      : Icons.table_chart_outlined,
                  color: AppTheme.primary,
                ),
                title: Text(
                  option.label,
                  style: AppText.labelMd.copyWith(color: AppTheme.onSurface),
                ),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: AppTheme.spaceSm),
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

/// Satu peminjaman sebagai kartu: siapa meminjam apa, sampai kapan, dan status.
class _LoanCard extends StatelessWidget {
  const _LoanCard({super.key, required this.detail, required this.onTap});

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
