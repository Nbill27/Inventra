import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/loan_detail.dart';
import '../models/loan_filter.dart';
import '../models/loan_stats.dart';
import '../providers/loan_provider.dart';
import '../widgets/app_chrome.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/loan_card.dart';
import '../widgets/panel.dart';
import '../widgets/section_header.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';

/// Beranda: ringkasan peminjaman plus daftar yang bisa dicari dan disaring.
///
/// Tab ini berlabel "Beranda" di bar bawah; riwayat lengkap dengan ekspor ada
/// di tab "Riwayat".
///
/// Isinya tiga angka pokok, kolom pencarian, chip filter pilih-satu, dan daftar
/// peminjaman. Semua angka datang dari query agregat di repository, jadi layar
/// ini tidak ikut melambat saat daftar peminjamannya panjang.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();

  /// Filter dan pencarian disimpan di layar ini, bukan di provider, supaya
  /// tidak ikut mengubah daftar di tab Riwayat.
  LoanFilter? _filter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Beranda adalah tab pertama, jadi ia memuat sendiri datanya: perpindahan
    // tab yang memicu muat ulang tidak terjadi saat aplikasi baru dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LoanProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _query = '');
  }

  /// Membuka layar lain, lalu menyegarkan daftar karena isinya bisa berubah.
  Future<void> _openScreen(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) {
      await context.read<LoanProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LoanProvider>();
    final loans = _visible(provider.loans);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openScreen(const LoanFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Catat pinjam'),
      ),
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  AppTheme.spaceSm,
                  AppTheme.spaceMd,
                  AppTheme.spaceMd,
                ),
                child: _MetricsRow(
                  loans: provider.stats,
                  isLoading: provider.isLoading,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  0,
                  AppTheme.spaceMd,
                  AppTheme.spaceSm,
                ),
                child: SearchField(
                  controller: _search,
                  hintText: 'Cari nama peminjam atau barang',
                  onChanged: _onSearchChanged,
                  onClear: _clearSearch,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  0,
                  AppTheme.spaceMd,
                  AppTheme.spaceSm,
                ),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filters(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.spaceMd,
                  0,
                  AppTheme.spaceMd,
                  AppTheme.spaceSm,
                ),
                child: SectionHeader(title: 'Daftar Peminjaman'),
              ),
              Expanded(child: _body(context, provider, loans)),
            ],
          ),
        ),
      ),
    );
  }

  /// Daftar yang lolos filter status dan kata kunci, disaring di memori.
  List<LoanDetail> _visible(List<LoanDetail> all) {
    final today = DateTime.now();
    return all
        .where(
          (detail) =>
              (_filter?.matches(detail.loan, today) ?? true) &&
              detail.matchesQuery(_query),
        )
        .toList();
  }

  /// Filter pilih-satu: "Semua" mengosongkan pilihan, chip kategori selalu
  /// menggantikan pilihan sebelumnya.
  List<Widget> _filters() {
    return [
      Padding(
        padding: const EdgeInsets.only(right: AppTheme.spaceSm),
        child: FilterPill(
          label: 'Semua',
          active: _filter == null,
          onTap: () => setState(() => _filter = null),
        ),
      ),
      for (final filter in LoanFilter.values)
        Padding(
          padding: const EdgeInsets.only(right: AppTheme.spaceSm),
          child: FilterPill(
            label: filter.label,
            active: _filter == filter,
            onTap: () => setState(() => _filter = filter),
          ),
        ),
    ];
  }

  Widget _body(
    BuildContext context,
    LoanProvider provider,
    List<LoanDetail> loans,
  ) {
    if (provider.errorMessage != null && loans.isEmpty) {
      return ErrorState(
        message: provider.errorMessage!,
        onRetry: () => context.read<LoanProvider>().load(),
      );
    }

    if (loans.isEmpty) {
      // Spinner hanya menggantikan layar saat belum ada isi; penyegaran tetap
      // menampilkan baris sebelumnya.
      if (provider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_query.trim().isNotEmpty) {
        return EmptyState(
          icon: Icons.search_off,
          title: 'Peminjaman tidak ditemukan',
          message: 'Tidak ada peminjaman yang cocok dengan "$_query".',
          actions: [
            OutlinedButton(
              onPressed: _clearSearch,
              child: const Text('Bersihkan pencarian'),
            ),
          ],
        );
      }
      if (_filter != null) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Tidak ada peminjaman di filter ini',
          message: 'Pilih "Semua" untuk melihat seluruh peminjaman.',
          actions: [
            OutlinedButton(
              onPressed: () => setState(() => _filter = null),
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
            onPressed: () => _openScreen(const LoanFormScreen()),
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
          return LoanCard(
            key: ValueKey(detail.loan.id),
            detail: detail,
            onTap: () => _openScreen(LoanDetailScreen(detail: detail)),
          );
        },
      ),
    );
  }
}

/// Tiga angka pokok peminjaman dalam satu baris.
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({required this.loans, required this.isLoading});

  final LoanStats loans;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight menyamakan tinggi ketiga kartu; tanpa itu, tinggi tiap
    // kartu mengikuti isinya sendiri dan barisnya terlihat bergerigi.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.outbox_outlined,
              value: loans.active,
              label: 'Dipinjam',
              caption: 'peminjaman aktif',
              color: AppTheme.primary,
              background: AppTheme.chip,
              isLoading: isLoading,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: _MetricCard(
              icon: Icons.warning_amber_rounded,
              value: loans.late,
              label: 'Terlambat',
              caption: 'perlu ditagih',
              color: AppTheme.danger,
              background: AppTheme.dangerSoft,
              isLoading: isLoading,
              highlighted: true,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: _MetricCard(
              icon: Icons.task_alt,
              value: loans.returned,
              label: 'Selesai',
              caption: 'total selesai',
              color: AppTheme.ok,
              background: AppTheme.okSoft,
              isLoading: isLoading,
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu angka pokok: label, kotak ikon, nilai besar, dan catatan kecil.
///
/// [highlighted] memakai latar penuh berwarna supaya kartu "Terlambat" langsung
/// terlihat tanpa harus dibaca.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.caption,
    required this.color,
    required this.background,
    required this.isLoading,
    this.highlighted = false,
  });

  final IconData icon;
  final int value;
  final String label;
  final String caption;
  final Color color;
  final Color background;
  final bool isLoading;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(AppTheme.space12),
      radius: AppTheme.radiusXl,
      fill: highlighted ? background : null,
      border: highlighted ? background : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.style(
                    size: 12,
                    weight: 600,
                    color: highlighted ? color : AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: highlighted ? color : background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: highlighted ? AppTheme.onPrimary : color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            isLoading ? '…' : formatCount(value),
            style: AppText.style(
              size: 22,
              weight: 700,
              color: highlighted ? color : AppTheme.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            caption,
            style: AppText.bodySm.copyWith(
              color: highlighted ? color : AppTheme.muted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
