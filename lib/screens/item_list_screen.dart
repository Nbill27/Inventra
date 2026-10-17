import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../models/item.dart';
import '../models/item_filter.dart';
import '../providers/item_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/app_chrome.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/status_pill.dart';
import 'item_form_screen.dart';
import 'item_import_screen.dart';

/// FR-B2, FR-B3 dan NFR-4: form peminjaman harus terjangkau dalam beberapa
/// ketukan, jadi daftar barang adalah hal pertama yang tampil di tab Barang.
class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Tanpa ini, setiap ketukan menjadi satu query database sementara admin
  /// masih mengetik nama barang.
  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      context.read<ItemProvider>().search(value);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    context.read<ItemProvider>().search('');
  }

  /// Filter pilih-satu: "Semua" mengosongkan pilihan, chip kategori selalu
  /// menggantikan pilihan sebelumnya.
  List<Widget> _filters(BuildContext context, ItemProvider provider) {
    final selected = provider.filter;
    return [
      Padding(
        padding: const EdgeInsets.only(right: AppTheme.spaceSm),
        child: FilterPill(
          label: 'Semua',
          active: selected == null,
          onTap: () => context.read<ItemProvider>().filterBy(null),
        ),
      ),
      for (final filter in ItemFilter.values)
        Padding(
          padding: const EdgeInsets.only(right: AppTheme.spaceSm),
          child: FilterPill(
            label: filter.label,
            active: selected == filter,
            onTap: () => context.read<ItemProvider>().filterBy(filter),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();
    final items = provider.items;

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
              'Barang',
              style: AppText.style(size: 20, weight: 700, color: AppTheme.ink),
            ),
            Text(
              provider.isLoading && items.isEmpty
                  ? 'Memuat…'
                  : '${items.length} barang',
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
            tooltip: 'Impor dari berkas',
            icon: Icons.upload_file,
            onTap: () => _open(const ItemImportScreen()),
          ),
          const SizedBox(width: AppTheme.spaceSm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const ItemFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
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
              child: SearchField(
                controller: _search,
                hintText: 'Cari nama atau kode barang',
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
                  children: _filters(context, provider),
                ),
              ),
            ),
            Expanded(child: _body(provider)),
          ],
        ),
      ),
    );
  }

  Widget _body(ItemProvider provider) {
    final items = provider.items;
    final isSearching = provider.query.trim().isNotEmpty;

    if (provider.errorMessage != null && items.isEmpty) {
      return ErrorState(
        message: provider.errorMessage!,
        onRetry: () => context.read<ItemProvider>().load(),
      );
    }

    if (items.isEmpty) {
      // Spinner hanya menggantikan layar saat belum ada isi; penyegaran tetap
      // menampilkan baris sebelumnya.
      if (provider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (isSearching) {
        return EmptyState(
          icon: Icons.search_off,
          title: 'Barang tidak ditemukan',
          message: provider.filter == null
              ? 'Tidak ada barang yang cocok dengan "${provider.query}".'
              : 'Tidak ada barang yang cocok dengan "${provider.query}" '
                  'di kategori terpilih.',
          actions: [
            OutlinedButton(
              onPressed: _clearSearch,
              child: const Text('Bersihkan pencarian'),
            ),
          ],
        );
      }
      if (provider.filter != null) {
        return EmptyState(
          icon: Icons.filter_alt_off_outlined,
          title: 'Tidak ada barang di kategori ini',
          message: 'Pilih "Semua" untuk melihat seluruh barang.',
          actions: [
            OutlinedButton(
              onPressed: () => context.read<ItemProvider>().filterBy(null),
              child: const Text('Lihat semua'),
            ),
          ],
        );
      }
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada barang',
        message: 'Tambahkan barang satu per satu, atau impor dari file '
            'Excel/CSV.',
        actions: [
          FilledButton.icon(
            onPressed: () => _open(const ItemImportScreen()),
            icon: const Icon(Icons.upload_file),
            label: const Text('Impor dari berkas'),
          ),
          OutlinedButton.icon(
            onPressed: () => _open(const ItemFormScreen()),
            icon: const Icon(Icons.add),
            label: const Text('Tambah manual'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ItemProvider>().load(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMd,
          0,
          AppTheme.spaceMd,
          AppTheme.spaceBottomBar,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space10),
        itemBuilder: (context, index) {
          final item = items[index];
          return _ItemCard(
            key: ValueKey(item.id),
            item: item,
            onTap: () => _open(ItemFormScreen(item: item)),
          );
        },
      ),
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

/// Satu barang sebagai kartu: nama dan kode, plus badge stok yang memerah saat
/// barang habis.
class _ItemCard extends StatelessWidget {
  const _ItemCard({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.chip,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  Icons.straighten,
                  size: 20,
                  color: AppTheme.link,
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
                        size: 14,
                        weight: 600,
                        color: AppTheme.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.code != null) ...[
                      const SizedBox(height: AppTheme.space2),
                      Text(
                        item.code!,
                        style: AppText.style(
                          size: 12,
                          weight: 400,
                          color: AppTheme.muted,
                        ).copyWith(height: 1.4),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceSm),
                    Wrap(
                      spacing: AppTheme.space6,
                      runSpacing: AppTheme.space6,
                      children: [
                        _StockBadge(item: item),
                        if (item.brand != null) _Tag(item.brand!),
                        if (item.status != null) _Tag(item.status!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              const Icon(Icons.chevron_right, size: 22, color: AppTheme.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tersedia dari total, memerah saat barang habis sepenuhnya.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final empty = item.stockAvailable == 0;
    return StatusPill(
      label: empty
          ? 'Habis'
          : 'Tersedia ${item.stockAvailable}/${item.stockTotal}',
      icon: empty ? Icons.block : Icons.inventory_2_outlined,
      background: empty ? AppTheme.dangerSoft : AppTheme.okSoft,
      foreground: empty ? AppTheme.danger : AppTheme.ok,
      upper: false,
      fontSize: 11,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space10,
        vertical: AppTheme.spaceXs,
      ),
    );
  }
}

/// Label tenang untuk bidang opsional, supaya tidak bersaing dengan stok.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: text,
      background: AppTheme.surfaceContainerLow,
      foreground: AppTheme.muted,
      upper: false,
      fontSize: 11,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.space10,
        vertical: AppTheme.spaceXs,
      ),
    );
  }
}
