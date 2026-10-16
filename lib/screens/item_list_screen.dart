import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import 'item_form_screen.dart';
import 'item_import_screen.dart';

/// FR-B2, FR-B3 and NFR-4: the loan form should be reachable in a few taps, so
/// the list is the first thing shown on the Barang tab.
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

  /// Without this, every keystroke is a database query while the admin is still
  /// typing a name.
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barang'),
        actions: [
          IconButton(
            tooltip: 'Impor dari berkas',
            onPressed: () => _open(const ItemImportScreen()),
            icon: const Icon(Icons.upload_file_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gap,
              4,
              AppTheme.gap,
              0,
            ),
            child: _searchField(context),
          ),
          Expanded(child: _body(provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const ItemFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Tambah barang'),
      ),
    );
  }

  /// A pill-shaped search field: rounded, filled, and with no visible border,
  /// so it reads as a search box rather than a form field.
  Widget _searchField(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _search,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cari nama atau kode barang',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Bersihkan pencarian',
                onPressed: _clearSearch,
                icon: const Icon(Icons.close),
              ),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: scheme.primary, width: 2),
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
      // The spinner only replaces the screen while there is nothing to show;
      // a refresh keeps the previous rows visible.
      if (provider.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (isSearching) {
        return EmptyState(
          icon: Icons.search_off,
          title: 'Barang tidak ditemukan',
          message: 'Tidak ada barang yang cocok dengan "${provider.query}".',
          action: OutlinedButton(
            onPressed: _clearSearch,
            child: const Text('Bersihkan pencarian'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Belum ada barang',
        message:
            'Tambahkan barang satu per satu, atau impor dari file Excel/CSV.',
        action: FilledButton.icon(
          onPressed: () => _open(const ItemImportScreen()),
          icon: const Icon(Icons.upload_file),
          label: const Text('Impor dari berkas'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => context.read<ItemProvider>().load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gap,
          8,
          AppTheme.gap,
          96,
        ),
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _countLabel(items.length, isSearching);
          }
          final item = items[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ItemCard(
              key: ValueKey(item.id),
              item: item,
              onTap: () => _open(ItemFormScreen(item: item)),
            ),
          );
        },
      ),
    );
  }

  Widget _countLabel(int count, bool isSearching) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          isSearching ? '$count hasil' : '$count barang',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

/// One item as a card: a leading tile, the name and code, and a stock badge that
/// turns red once nothing is left.
class _ItemCard extends StatelessWidget {
  const _ItemCard({super.key, required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.straighten,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.code != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.code!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _StockBadge(item: item),
                        if (item.brand != null) _Tag(item.brand!),
                        if (item.status != null) _Tag(item.status!),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

/// Available-over-total, coloured red when the item is fully out.
class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = item.stockAvailable == 0;
    final background =
        empty ? scheme.errorContainer : scheme.primaryContainer;
    final foreground =
        empty ? scheme.onErrorContainer : scheme.onPrimaryContainer;

    return _Pill(
      background: background,
      foreground: foreground,
      icon: empty ? Icons.block : Icons.inventory_2_outlined,
      label: empty
          ? 'Habis'
          : 'Tersedia ${item.stockAvailable}/${item.stockTotal}',
      bold: true,
    );
  }
}

/// A quiet label for the optional fields, so they do not compete with stock.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Pill(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurfaceVariant,
      label: text,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.background,
    required this.foreground,
    required this.label,
    this.icon,
    this.bold = false,
  });

  final Color background;
  final Color foreground;
  final String label;
  final IconData? icon;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
