import 'package:flutter/material.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../models/item.dart';
import 'app_chrome.dart';
import 'status_pill.dart';

/// Membuka pemilih barang dan mengembalikan `id` yang dipilih, atau null kalau
/// ditutup tanpa memilih.
///
/// Dipakai menggantikan `DropdownButton` biasa. Alasannya: daftar barang bisa
/// berisi puluhan ribu baris, dan dropdown membangun seluruh isinya sekaligus
/// lalu menuntut pengguna menggulir untuk menemukan satu nama. Di sini daftar
/// disaring dulu lewat pencarian, dan hanya baris yang tampak yang dibangun.
Future<int?> showItemPicker(
  BuildContext context, {
  required List<Item> items,
  required int Function(Item item) availableFor,
  int? selectedId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      // Tinggi dipatok eksplisit supaya daftar selalu punya batas tinggi yang
      // jelas, berapa pun ukuran layarnya.
      height: MediaQuery.sizeOf(sheetContext).height * 0.9,
      child: _ItemPickerSheet(
        items: items,
        availableFor: availableFor,
        selectedId: selectedId,
      ),
    ),
  );
}

class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({
    required this.items,
    required this.availableFor,
    this.selectedId,
  });

  final List<Item> items;
  final int Function(Item item) availableFor;
  final int? selectedId;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Barang yang stoknya nol tetap ditampilkan (supaya pengguna tahu barangnya
  /// ada, cuma habis) tetapi tidak bisa dipilih, kecuali yang sedang terpilih
  /// di peminjaman yang dibuka.
  bool _selectable(Item item) =>
      widget.availableFor(item) > 0 || item.id == widget.selectedId;

  List<Item> get _results {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.items;
    }
    return [
      for (final item in widget.items)
        if (item.name.toLowerCase().contains(query) ||
            (item.code?.toLowerCase().contains(query) ?? false))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd,
            0,
            AppTheme.spaceMd,
            AppTheme.spaceSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Pilih barang',
                  style: AppText.headlineSm.copyWith(color: AppTheme.ink),
                ),
              ),
              Text(
                '${results.length} dari ${widget.items.length}',
                style: AppText.bodySm.copyWith(color: AppTheme.muted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
          child: SearchField(
            controller: _search,
            hintText: 'Cari nama atau kode barang',
            onChanged: (_) => setState(() {}),
            onClear: () {
              _search.clear();
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    child: Text(
                      'Tidak ada barang yang cocok dengan "${_search.text.trim()}".',
                      textAlign: TextAlign.center,
                      style: AppText.bodyMd.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceMd,
                    0,
                    AppTheme.spaceMd,
                    AppTheme.spaceLg,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return _ItemOption(
                      item: item,
                      available: widget.availableFor(item),
                      selected: item.id == widget.selectedId,
                      selectable: _selectable(item),
                      onTap: () => Navigator.of(context).pop(item.id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Satu baris barang di dalam pemilih.
class _ItemOption extends StatelessWidget {
  const _ItemOption({
    required this.item,
    required this.available,
    required this.selected,
    required this.selectable,
    required this.onTap,
  });

  final Item item;
  final int available;
  final bool selected;
  final bool selectable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final habis = available == 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Material(
        color: selected
            ? AppTheme.primaryContainer
            : AppTheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          side: BorderSide(
            color: selected ? AppTheme.primary : AppTheme.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selectable ? onTap : null,
          child: Opacity(
            opacity: selectable ? 1 : 0.55,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space12),
              child: Row(
                children: [
                  Container(
                    width: AppTheme.touch,
                    height: AppTheme.touch,
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
                            size: 13.5,
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
                            style: AppText.bodySm.copyWith(
                              color: AppTheme.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: AppTheme.space6),
                        StatusPill(
                          label: habis ? 'Habis' : 'Tersedia $available',
                          background: habis
                              ? AppTheme.dangerSoft
                              : AppTheme.okSoft,
                          foreground: habis ? AppTheme.danger : AppTheme.ok,
                          upper: false,
                          fontSize: 11,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.space10,
                            vertical: AppTheme.spaceXs,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Icon(
                    selected ? Icons.check_circle : Icons.chevron_right,
                    size: 22,
                    color: selected ? AppTheme.primary : AppTheme.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
