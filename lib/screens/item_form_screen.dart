import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/section_title.dart';

/// Serves both "tambah barang" (FR-B1) and "ubah barang" (FR-B5), including the
/// delete action (FR-B6) which is only offered in edit mode.
///
/// Merged on purpose: the fields are identical, and a separate detail screen
/// would only have been a third route to the same form.
class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, this.item});

  /// Null means create mode.
  final Item? item;

  bool get isEditing => item != null;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _noUrut;
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _range;
  late final TextEditingController _brand;
  late final TextEditingController _pic;
  late final TextEditingController _status;
  late final TextEditingController _stockTotal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _noUrut = TextEditingController(text: item?.noUrut ?? '');
    _name = TextEditingController(text: item?.name ?? '');
    _code = TextEditingController(text: item?.code ?? '');
    _range = TextEditingController(text: item?.range ?? '');
    _brand = TextEditingController(text: item?.brand ?? '');
    _pic = TextEditingController(text: item?.pic ?? '');
    _status = TextEditingController(text: item?.status ?? '');
    _stockTotal = TextEditingController(
      text: item == null ? '' : item.stockTotal.toString(),
    );
  }

  @override
  void dispose() {
    _noUrut.dispose();
    _name.dispose();
    _code.dispose();
    _range.dispose();
    _brand.dispose();
    _pic.dispose();
    _status.dispose();
    _stockTotal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final borrowed = item?.borrowed ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Ubah Barang' : 'Tambah Barang'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gap,
            AppTheme.gap,
            AppTheme.gap,
            32,
          ),
          children: [
            const SectionTitle(
              icon: Icons.badge_outlined,
              label: 'Identitas alat',
            ),
            TextFormField(
              controller: _noUrut,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'No',
                helperText: 'Opsional. Nomor urut pada daftar alat ukur.',
              ),
            ),
            const SizedBox(height: AppTheme.gap),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nama alat ukur',
                helperText: 'Wajib. Contoh: Digital Caliper',
              ),
              validator: (value) => _requiredText(value, 'Nama alat ukur'),
            ),
            const SizedBox(height: AppTheme.gap),
            TextFormField(
              controller: _code,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Kode alat ukur',
                helperText: 'Opsional. Dipakai mencocokkan duplikat saat impor.',
              ),
            ),

            const SizedBox(height: 28),
            const SectionTitle(
              icon: Icons.tune,
              label: 'Spesifikasi',
            ),
            TextFormField(
              controller: _range,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Range',
                helperText: 'Opsional. Contoh: 150 mm',
              ),
            ),
            const SizedBox(height: AppTheme.gap),
            TextFormField(
              controller: _brand,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Brand',
                helperText: 'Opsional. Contoh: Mitutoyo',
              ),
            ),
            const SizedBox(height: AppTheme.gap),
            TextFormField(
              controller: _pic,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'PIC',
                helperText: 'Opsional. Penanggung jawab. Contoh: QC',
              ),
            ),
            const SizedBox(height: AppTheme.gap),
            TextFormField(
              controller: _status,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Status',
                helperText: 'Opsional. Contoh: OK atau Not Good / Rusak',
              ),
            ),

            const SizedBox(height: 28),
            const SectionTitle(
              icon: Icons.inventory_2_outlined,
              label: 'Stok',
            ),
            TextFormField(
              controller: _stockTotal,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Stok total',
                helperText: widget.isEditing
                    ? '$borrowed unit sedang dipinjam. Nilai di bawah $borrowed akan ditolak.'
                    : 'Wajib. Barang baru langsung tersedia sebanyak ini.',
              ),
              validator: _stockValidator,
            ),

            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Hapus barang'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _requiredText(String? value, String field) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return '$field wajib diisi.';
    }
    if (text.length > 100) {
      return '$field maksimal 100 karakter.';
    }
    return null;
  }

  String? _stockValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Stok total wajib diisi.';
    }
    final parsed = int.tryParse(text);
    if (parsed == null) {
      return 'Stok total harus angka bulat.';
    }
    if (parsed < 0) {
      return 'Stok total tidak boleh negatif.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final provider = context.read<ItemProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final existing = widget.item;
    final stockTotal = int.parse(_stockTotal.text.trim());

    setState(() => _saving = true);

    final draft = Item(
      id: existing?.id,
      noUrut: _noUrut.text,
      name: _name.text,
      code: _code.text,
      range: _range.text,
      brand: _brand.text,
      pic: _pic.text,
      status: _status.text,
      stockTotal: stockTotal,
      // On create the item is fully available. On update the repository derives
      // availability from the borrowed count, so this value is not the source
      // of truth there.
      stockAvailable: existing?.stockAvailable ?? stockTotal,
    );

    final error = existing == null
        ? await provider.create(draft)
        : await provider.update(draft);

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Barang ditambahkan.' : 'Perubahan barang disimpan.',
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item?.id == null) {
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: 'Hapus barang?',
      message:
          '"${item!.name}" akan dihapus. Penghapusan ditolak kalau barang masih terhubung ke peminjaman.',
      confirmLabel: 'Hapus',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final provider = context.read<ItemProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);
    final error = await provider.delete(item.id!);

    if (!mounted) {
      return;
    }
    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Barang dihapus.')));
  }
}
