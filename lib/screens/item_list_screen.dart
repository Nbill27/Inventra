import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final isSearching = provider.query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barang'),
        actions: [
          IconButton(
            tooltip: 'Impor dari berkas',
            onPressed: () => _open(const ItemImportScreen()),
            icon: const Icon(Icons.upload_file),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
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
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Expanded(child: _body(provider, isSearching)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const ItemFormScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Barang'),
      ),
    );
  }

  Widget _body(ItemProvider provider, bool isSearching) {
    final items = provider.items;

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
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => _row(items[index]),
      ),
    );
  }

  Widget _row(Item item) => ListTile(
        title: Text(item.name),
        subtitle: Text(_subtitle(item)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(ItemFormScreen(item: item)),
      );

  String _subtitle(Item item) => [
        if (item.code != null) 'Kode ${item.code}',
        if (item.brand != null) item.brand!,
        if (item.status != null) item.status!,
        'Tersedia ${item.stockAvailable} dari ${item.stockTotal}',
      ].join(' - ');

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
