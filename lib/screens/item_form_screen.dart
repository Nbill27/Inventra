import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/item.dart';
import '../providers/item_provider.dart';
import '../widgets/confirm_dialog.dart';

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
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _category;
  late final TextEditingController _stockTotal;
  late final TextEditingController _note;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _code = TextEditingController(text: item?.code ?? '');
    _category = TextEditingController(text: item?.category ?? '');
    _stockTotal = TextEditingController(
      text: item == null ? '' : item.stockTotal.toString(),
    );
    _note = TextEditingController(text: item?.note ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _category.dispose();
    _stockTotal.dispose();
    _note.dispose();
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
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nama barang',
                helperText: 'Wajib. Contoh: Proyektor Epson EB-X06',
                border: OutlineInputBorder(),
              ),
              validator: (value) => _requiredText(value, 'Nama barang'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _code,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Kode barang',
                helperText: 'Opsional. Dipakai untuk mencocokkan duplikat saat impor CSV.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _category,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                helperText: 'Opsional. Contoh: Elektronik',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockTotal,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Stok total',
                helperText: widget.isEditing
                    ? '$borrowed unit sedang dipinjam. Nilai di bawah $borrowed akan ditolak.'
                    : 'Wajib. Barang baru langsung tersedia sebanyak ini.',
                border: const OutlineInputBorder(),
              ),
              validator: _stockValidator,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'Catatan',
                helperText: 'Opsional. Contoh: rak A, unit A saja yang berfungsi.',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
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
      name: _name.text,
      code: _code.text,
      category: _category.text,
      stockTotal: stockTotal,
      // On create the item is fully available. On update the repository derives
      // availability from the borrowed count, so this value is not the source
      // of truth there.
      stockAvailable: existing?.stockAvailable ?? stockTotal,
      note: _note.text,
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
