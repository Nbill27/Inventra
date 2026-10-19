import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../models/loan_stats.dart';
import '../providers/loan_provider.dart';
import '../services/loan_export_service.dart';
import '../widgets/app_background.dart';
import '../widgets/app_chrome.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/history_card.dart';
import '../widgets/panel.dart';
import 'loan_detail_screen.dart';

/// Filter khas layar Riwayat.
///
/// Beda dari chip Beranda: layar ini memuat seluruh peminjaman, jadi
/// "Terlambat" juga mencakup yang dikembalikan melewati tenggat, dan ada
/// "Tepat Waktu" untuk arsip yang kembali sesuai jadwal.
enum _HistoryFilter {
  borrowed('Dipinjam'),
  onTime('Tepat Waktu'),
  late('Terlambat'),
  returned('Selesai');

  const _HistoryFilter(this.label);

  final String label;

  bool matches(Loan loan, DateTime today) {
    final returnDate = loan.returnDate;
    return switch (this) {
      _HistoryFilter.borrowed => loan.status == LoanStatus.borrowed,
      _HistoryFilter.onTime =>
        loan.status == LoanStatus.returned &&
            !isBeforeDay(loan.dueDate, returnDate ?? today),
      _HistoryFilter.late => loan.status == LoanStatus.borrowed
          ? isBeforeDay(loan.dueDate, today)
          : isBeforeDay(loan.dueDate, returnDate ?? today),
      _HistoryFilter.returned => loan.status == LoanStatus.returned,
    };
  }
}

/// Riwayat peminjaman: statistik arsip, pencarian, pemilih periode, filter
/// status, ekspor, dan daftar yang dikelompokkan per bulan.
///
/// Penyaringan dilakukan di memori atas seluruh daftar dari provider, sehingga
/// filter di Beranda tidak ikut mengubah isi layar ini.
class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  static const _exportService = LoanExportService();

  final _search = TextEditingController();

  _HistoryFilter? _filter;
  String _periodKey = 'all';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) => setState(() => _query = value);

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  /// Bulan yang dipilih, atau null untuk seluruh periode.
  DateTime? _periodFrom(String key) {
    if (key == 'all') {
      return null;
    }
    final parts = key.split('-');
    if (parts.length != 2) {
      return null;
    }
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) {
      return null;
    }
    return DateTime(year, month);
  }

  String _keyFor(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  /// Kunci bulan yang benar-benar ada di data, terbaru lebih dulu.
  List<String> _periodKeys(List<LoanDetail> loans) {
    final keys = <String>{};
    for (final detail in loans) {
      keys.add(
        _keyFor(
          DateTime(detail.loan.loanDate.year, detail.loan.loanDate.month),
        ),
      );
    }
    return keys.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Daftar yang lolos pencarian, filter status, dan periode.
  ///
  /// [today] datang dari provider supaya kategori "Terlambat" sama dengan yang
  /// dipakai ringkasan, walau aplikasi sudah lewat tengah malam.
  List<LoanDetail> _visible(List<LoanDetail> all, String periodKey, DateTime today) {
    final period = _periodFrom(periodKey);
    return all.where((detail) {
      final loan = detail.loan;
      if (!detail.matchesQuery(_query)) {
        return false;
      }
      if (_filter != null && !_filter!.matches(loan, today)) {
        return false;
      }
      if (period != null &&
          (loan.loanDate.year != period.year ||
              loan.loanDate.month != period.month)) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loans = provider.loans;
    final periodKeys = _periodKeys(loans);
    // Bulan yang dipilih bisa hilang setelah data berubah; jatuh ke semua
    // periode supaya daftar tidak terjebak kosong.
    final periodKey = periodKeys.contains(_periodKey) ? _periodKey : 'all';
    final visible = _visible(loans, periodKey, provider.today);

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
              'Riwayat',
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
      ),
      body: ContentWidth(
        child: RefreshIndicator(
          onRefresh: () => context.read<LoanProvider>().load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMd,
              AppTheme.spaceSm,
              AppTheme.spaceMd,
              AppTheme.spaceBottomBar,
            ),
            children: [
              _ArchiveStats(stats: provider.stats, isLoading: provider.isLoading),
              const SizedBox(height: AppTheme.spaceMd),
              SearchField(
                controller: _search,
                hintText: 'Cari barang atau nama peminjam',
                onChanged: _onSearchChanged,
                onClear: _clearSearch,
              ),
              const SizedBox(height: AppTheme.spaceSm),
              _periodPicker(periodKeys, periodKey),
              const SizedBox(height: AppTheme.spaceSm),
              _chips(),
              const SizedBox(height: AppTheme.spaceMd),
              _ExportBanner(
                onTap: visible.isEmpty
                    ? null
                    : () => _export(context, visible),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              ..._content(context, provider, visible, periodKey),
            ],
          ),
        ),
      ),
    );
  }

  /// Pemilih periode dibangun dari bulan yang benar-benar ada di data, jadi
  /// tidak pernah menawarkan bulan kosong.
  Widget _periodPicker(List<String> keys, String value) {
    return Panel(
      radius: AppTheme.radiusXl,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppTheme.muted,
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  isDense: true,
                  value: value,
                  icon: const Icon(
                    Icons.expand_more,
                    size: 20,
                    color: AppTheme.muted,
                  ),
                  style: AppText.style(
                    size: 13,
                    weight: 600,
                    color: AppTheme.ink,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('Semua periode'),
                    ),
                    for (final key in keys)
                      DropdownMenuItem(
                        value: key,
                        child: Text(formatMonthYear(_periodFrom(key)!)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _periodKey = value ?? 'all'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filter pilih-satu: "Semua" mengosongkan pilihan.
  Widget _chips() {
    return SizedBox(
      height: AppTheme.touch,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppTheme.spaceSm),
            child: FilterPill(
              label: 'Semua',
              active: _filter == null,
              onTap: () => setState(() => _filter = null),
            ),
          ),
          for (final filter in _HistoryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppTheme.spaceSm),
              child: FilterPill(
                label: filter.label,
                active: _filter == filter,
                onTap: () => setState(() => _filter = filter),
              ),
            ),
        ],
      ),
    );
  }

  /// Isi daftar: keadaan kosong/galat, atau kelompok bulan berisi kartu.
  List<Widget> _content(
    BuildContext context,
    LoanProvider provider,
    List<LoanDetail> visible,
    String periodKey,
  ) {
    if (provider.errorMessage != null && provider.loans.isEmpty) {
      return [
        SizedBox(
          height: 320,
          child: ErrorState(
            message: provider.errorMessage!,
            onRetry: () => context.read<LoanProvider>().load(),
          ),
        ),
      ];
    }

    if (provider.loans.isEmpty) {
      if (provider.isLoading) {
        return const [
          SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          ),
        ];
      }
      return [
        SizedBox(
          height: 320,
          child: EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Belum ada peminjaman',
            message: 'Catat peminjaman pertama lewat tab Beranda.',
          ),
        ),
      ];
    }

    if (visible.isEmpty) {
      return [_emptyResult(periodKey)];
    }

    final groups = <DateTime, List<LoanDetail>>{};
    for (final detail in visible) {
      final month = DateTime(
        detail.loan.loanDate.year,
        detail.loan.loanDate.month,
      );
      groups.putIfAbsent(month, () => []).add(detail);
    }
    final orderedMonths = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (var i = 0; i < orderedMonths.length; i++) ...[
        if (i > 0) const SizedBox(height: AppTheme.spaceMd),
        _MonthHeader(
          month: orderedMonths[i],
          count: groups[orderedMonths[i]]!.length,
        ),
        const SizedBox(height: AppTheme.spaceSm),
        for (var j = 0; j < groups[orderedMonths[i]]!.length; j++) ...[
          if (j > 0) const SizedBox(height: AppTheme.spaceSm),
          HistoryCard(
            key: ValueKey(groups[orderedMonths[i]]![j].loan.id),
            detail: groups[orderedMonths[i]]![j],
            onTap: () => _openDetail(context, groups[orderedMonths[i]]![j]),
          ),
        ],
      ],
      const SizedBox(height: AppTheme.spaceLg),
      Center(
        child: Text(
          'Semua ${visible.length} rekaman ditampilkan',
          style: AppText.bodySm.copyWith(color: AppTheme.muted),
        ),
      ),
    ];
  }

  Widget _emptyResult(String periodKey) {
    if (_query.trim().isNotEmpty) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          icon: Icons.search_off,
          title: 'Peminjaman tidak ditemukan',
          message: 'Tidak ada peminjaman yang cocok dengan "$_query".',
          actions: [
            OutlinedButton(
              onPressed: _clearSearch,
              child: const Text('Bersihkan pencarian'),
            ),
          ],
        ),
      );
    }
    if (_filter != null) {
      return SizedBox(
        height: 320,
        child: EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Tidak ada peminjaman di filter ini',
          message: 'Pilih "Semua" untuk melihat seluruh riwayat.',
          actions: [
            OutlinedButton(
              onPressed: () => setState(() => _filter = null),
              child: const Text('Lihat semua'),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 320,
      child: EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Tidak ada peminjaman di periode ini',
        message: 'Pilih periode lain atau kembali ke semua periode.',
        actions: [
          OutlinedButton(
            onPressed: () => setState(() => _periodKey = 'all'),
            child: const Text('Semua periode'),
          ),
        ],
      ),
    );
  }

  void _openDetail(BuildContext context, LoanDetail detail) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoanDetailScreen(detail: detail)),
    );
  }

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
}

/// Kartu ringkasan arsip: total transaksi, ketepatan waktu, dan rerata durasi.
class _ArchiveStats extends StatelessWidget {
  const _ArchiveStats({required this.stats, required this.isLoading});

  final LoanStats stats;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: AppTheme.radiusXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 20,
                color: AppTheme.primary,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Expanded(
                child: Text(
                  'Arsip Peminjaman',
                  style: AppText.headlineSm.copyWith(fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Text(
                  'Akumulatif',
                  style: AppText.style(
                    size: 10,
                    weight: 600,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ArchiveStat(
                    label: 'Total',
                    value: '${stats.total}',
                    unit: 'transaksi',
                    caption: '${stats.returned} selesai',
                    color: AppTheme.primary,
                    background: AppTheme.chip,
                    isLoading: isLoading,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceXs),
                Expanded(
                  child: _ArchiveStat(
                    label: 'Tepat Waktu',
                    value: '${(stats.onTimeRate * 100).round()}',
                    unit: '%',
                    caption:
                        '${stats.onTime} dari ${stats.returned} selesai',
                    color: AppTheme.ok,
                    background: AppTheme.okSoft,
                    isLoading: isLoading,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceXs),
                Expanded(
                  child: _ArchiveStat(
                    label: 'Rerata',
                    // Rerata 0 hari artinya pinjaman selesai di hari yang sama
                    // dengan hari pengajuan, jadi angka 0,0 diganti tanda pisah
                    // supaya tidak terbaca seolah data tidak terisi.
                    value: stats.averageLoanDays > 0
                        ? stats.averageLoanDays.toStringAsFixed(1)
                        : '—',
                    unit: stats.averageLoanDays > 0 ? 'hari' : '',
                    caption: stats.averageLoanDays > 0
                        ? 'siklus pinjam'
                        : 'selesai di hari yang sama',
                    color: AppTheme.ink,
                    background: AppTheme.surfaceContainerLow,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu angka arsip dengan latar lembut.
class _ArchiveStat extends StatelessWidget {
  const _ArchiveStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.caption,
    required this.color,
    required this.background,
    required this.isLoading,
  });

  final String label;
  final String value;
  final String unit;
  final String caption;
  final Color color;
  final Color background;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.space10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: AppText.upper(size: 9, weight: 700, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.spaceXs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  isLoading ? '…' : value,
                  style: AppText.style(
                    size: 22,
                    weight: 700,
                    color: color,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 2),
                  Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Text(
                      unit,
                      style: AppText.style(
                        size: 10,
                        weight: 500,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            caption,
            style: AppText.bodySm.copyWith(fontSize: 10.5, color: color),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Banner ekspor di atas daftar.
class _ExportBanner extends StatelessWidget {
  const _ExportBanner({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      fill: AppTheme.primary,
      border: AppTheme.primary,
      radius: AppTheme.radiusXl,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.cardSolid,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Icon(
              Icons.sim_card_download_outlined,
              size: 20,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ekspor Rekap Riwayat',
                  style: AppText.style(
                    size: 14,
                    weight: 700,
                    color: AppTheme.onPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Format XLSX & CSV',
                  style: AppText.style(
                    size: 11.5,
                    weight: 500,
                    color: AppTheme.lavender,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.cardSolid,
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
                vertical: AppTheme.space10,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Ekspor'),
          ),
        ],
      ),
    );
  }
}

/// Judul kelompok bulan di atas kartu-kartunya.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month, required this.count});

  final DateTime month;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_month_outlined,
          size: 16,
          color: AppTheme.muted,
        ),
        const SizedBox(width: AppTheme.spaceXs),
        Expanded(
          child: Text(
            formatMonthYear(month).toUpperCase(),
            style: AppText.upper(size: 11, weight: 700, color: AppTheme.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppTheme.spaceSm),
        Text(
          '$count transaksi',
          style: AppText.style(size: 11, weight: 500, color: AppTheme.muted),
        ),
      ],
    );
  }
}
