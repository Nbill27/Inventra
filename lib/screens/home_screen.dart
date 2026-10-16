import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/formatters.dart';
import '../models/item_stats.dart';
import '../models/loan_detail.dart';
import '../models/loan_stats.dart';
import '../providers/home_provider.dart';
import '../widgets/content_width.dart';
import '../widgets/loan_card.dart';
import '../widgets/panel.dart';
import '../widgets/section_header.dart';
import 'item_form_screen.dart';
import 'item_import_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';

/// Beranda: satu layar untuk tahu keadaan gudang alat tanpa membuka daftar.
///
/// Isinya ringkasan angka, peminjaman terbaru, dan pintasan ke aksi yang paling
/// sering dipakai. Semua angka datang dari query agregat di repository, jadi
/// layar ini tidak ikut melambat saat daftar barangnya panjang.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onBukaTab});

  /// Pindah tab di [HomeShell]: 0 Beranda, 1 Barang, 2 Peminjaman.
  final ValueChanged<int>? onBukaTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Beranda adalah tab pertama, jadi ia memuat sendiri datanya: perpindahan
    // tab yang memicu muat ulang tidak terjadi saat aplikasi baru dibuka.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HomeProvider>().load();
      }
    });
  }

  /// Membuka layar lain, lalu menyegarkan ringkasan karena isinya bisa berubah.
  Future<void> _bukaHalaman(Widget halaman) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => halaman),
    );
    if (mounted) {
      await context.read<HomeProvider>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => context.read<HomeProvider>().load(),
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                AppTheme.spaceSm,
                AppTheme.spaceMd,
                AppTheme.spaceBottomBar,
              ),
              children: [
                const _Hero(),
                const SizedBox(height: AppTheme.spaceMd),
                _StatsGrid(
                  items: provider.itemStats,
                  loans: provider.loanStats,
                  memuat: provider.isLoading,
                ),
                const SizedBox(height: AppTheme.spaceLg),
                SectionHeader(
                  title: 'Peminjaman terbaru',
                  trailingLabel: 'Lihat semua',
                  onTrailingTap: () => widget.onBukaTab?.call(2),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                _RecentList(
                  daftar: provider.recent,
                  memuat: provider.isLoading,
                  onTapItem: (detail) =>
                      _bukaHalaman(LoanDetailScreen(detail: detail)),
                  onLihatSemua: () => widget.onBukaTab?.call(2),
                ),
                const SizedBox(height: AppTheme.spaceLg),
                const SectionHeader(title: 'Aksi cepat'),
                const SizedBox(height: AppTheme.spaceSm),
                _QuickActions(
                  onCatatPinjam: () =>
                      _bukaHalaman(const LoanFormScreen()),
                  onTambahBarang: () =>
                      _bukaHalaman(const ItemFormScreen()),
                  onImpor: () => _bukaHalaman(const ItemImportScreen()),
                  onLihatBarang: () => widget.onBukaTab?.call(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Blok identitas di atas permukaan biru pekat solid, tanpa gradien.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.deep,
        borderRadius: BorderRadius.circular(AppTheme.radiusPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Text(
                  'PB',
                  style: AppText.style(
                    size: 12,
                    weight: 700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space12),
              Expanded(
                child: Text(
                  'Peminjaman Barang',
                  style: AppText.headlineSm.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Text(
            'Pinjam dan kembali\ntercatat otomatis',
            style: AppText.headlineLg.copyWith(
              fontSize: 28,
              height: 1.12,
              letterSpacing: -0.6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'Stok berkurang saat dipinjam, dan kembali saat peminjaman '
            'ditandai selesai.',
            style: AppText.bodySm.copyWith(
              fontSize: 13,
              height: 1.45,
              color: const Color(0xCCFFFFFF),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const _OfflinePill(),
        ],
      ),
    );
  }
}

/// Aplikasi tidak punya server, jadi statusnya selalu data lokal.
class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.space10,
          AppTheme.space6,
          AppTheme.space12,
          AppTheme.space6,
        ),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF9CCBFF),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Text(
              'Mode offline, data lokal',
              style: AppText.style(
                size: 12,
                weight: 500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empat angka pokok dalam susunan dua kolom.
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.items,
    required this.loans,
    required this.memuat,
  });

  final ItemStats items;
  final LoanStats loans;
  final bool memuat;

  @override
  Widget build(BuildContext context) {
    final barang = items.totalItems;
    final dipinjam = loans.activeUnits;
    final terlambat = loans.late;
    final habis = items.outOfStock;

    return Column(
      children: [
        _Pair(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.inventory_2_outlined,
                value: formatCount(barang),
                label: 'Barang terdaftar',
                catatan: '${formatCount(items.totalUnits)} unit',
                warna: AppTheme.primary,
                latar: AppTheme.primaryContainer,
                memuat: memuat,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: _StatCard(
                icon: Icons.assignment_outlined,
                value: formatCount(dipinjam),
                label: 'Sedang dipinjam',
                catatan: '${formatCount(loans.active)} peminjaman aktif',
                warna: AppTheme.link,
                latar: AppTheme.chip,
                memuat: memuat,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _Pair(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.schedule,
                value: formatCount(terlambat),
                label: 'Terlambat',
                catatan: terlambat == 0
                    ? 'semua tepat waktu'
                    : 'lewat tanggal kembali',
                warna: AppTheme.danger,
                latar: AppTheme.dangerSoft,
                memuat: memuat,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: _StatCard(
                icon: Icons.block,
                value: formatCount(habis),
                label: 'Stok habis',
                catatan: habis == 0 ? 'semua tersedia' : 'barang tidak tersedia',
                warna: AppTheme.warn,
                latar: AppTheme.warnSoft,
                memuat: memuat,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Satu angka pokok: ikon berwarna, nilai besar, label, dan catatan kecil.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.catatan,
    required this.warna,
    required this.latar,
    required this.memuat,
  });

  final IconData icon;
  final String value;
  final String label;
  final String catatan;
  final Color warna;
  final Color latar;
  final bool memuat;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(AppTheme.space12),
      radius: AppTheme.radiusXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: latar,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Icon(icon, size: 20, color: warna),
          ),
          const SizedBox(height: AppTheme.space12),
          Text(
            memuat ? '…' : value,
            style: AppText.headlineMd.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            label,
            style: AppText.style(size: 12.5, weight: 600, color: AppTheme.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            catatan,
            style: AppText.bodySm.copyWith(color: AppTheme.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Peminjaman terbaru, atau ajakan memulai saat riwayatnya masih kosong.
class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.daftar,
    required this.memuat,
    required this.onTapItem,
    required this.onLihatSemua,
  });

  final List<LoanDetail> daftar;
  final bool memuat;
  final ValueChanged<LoanDetail> onTapItem;
  final VoidCallback onLihatSemua;

  @override
  Widget build(BuildContext context) {
    if (memuat && daftar.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (daftar.isEmpty) {
      return Panel(
        radius: AppTheme.radiusXl,
        child: Row(
          children: [
            const Icon(Icons.history, size: 22, color: AppTheme.muted),
            const SizedBox(width: AppTheme.space10),
            Expanded(
              child: Text(
                'Belum ada peminjaman tercatat.',
                style: AppText.bodySm.copyWith(color: AppTheme.muted),
              ),
            ),
            TextButton(
              onPressed: onLihatSemua,
              child: const Text('Buka'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < daftar.length; i++) ...[
          if (i > 0) const SizedBox(height: AppTheme.spaceSm),
          LoanCard(
            detail: daftar[i],
            onTap: () => onTapItem(daftar[i]),
          ),
        ],
      ],
    );
  }
}

/// Pintasan ke aksi yang paling sering dipakai, dua kolom.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCatatPinjam,
    required this.onTambahBarang,
    required this.onImpor,
    required this.onLihatBarang,
  });

  final VoidCallback onCatatPinjam;
  final VoidCallback onTambahBarang;
  final VoidCallback onImpor;
  final VoidCallback onLihatBarang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Pair(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.add_task,
                title: 'Catat pinjam',
                subtitle: 'Peminjaman baru',
                utama: true,
                onTap: onCatatPinjam,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: _ActionCard(
                icon: Icons.upload_file,
                title: 'Impor berkas',
                subtitle: 'Excel atau CSV',
                onTap: onImpor,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _Pair(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.add_box_outlined,
                title: 'Tambah barang',
                subtitle: 'Daftarkan alat',
                onTap: onTambahBarang,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: _ActionCard(
                icon: Icons.inventory_2_outlined,
                title: 'Lihat barang',
                subtitle: 'Daftar dan stok',
                onTap: onLihatBarang,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dua kartu berdampingan dengan tinggi yang disamakan.
///
/// `IntrinsicHeight` wajib di sini: `CrossAxisAlignment.stretch` di dalam
/// `ListView` yang tingginya tak terbatas akan meminta tinggi tak hingga,
/// dan seluruh daftar gagal digambar.
class _Pair extends StatelessWidget {
  const _Pair({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Kartu pintasan. Versi [utama] memakai biru penuh sebagai aksi terpenting.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.utama = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool utama;

  @override
  Widget build(BuildContext context) {
    final latar = utama ? AppTheme.primary : AppTheme.cardSolid;
    final judul = utama ? Colors.white : AppTheme.ink;
    final sub = utama ? const Color(0xCCFFFFFF) : AppTheme.muted;
    final ikon = utama ? Colors.white : AppTheme.primary;

    return Material(
      color: latar,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        side: utama
            ? BorderSide.none
            : const BorderSide(color: AppTheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: ikon),
              const SizedBox(height: AppTheme.space12),
              Text(
                title,
                style: AppText.style(size: 13.5, weight: 600, color: judul),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.space2),
              Text(
                subtitle,
                style: AppText.bodySm.copyWith(color: sub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
