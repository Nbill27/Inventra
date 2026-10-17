import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../models/item.dart';
import '../providers/item_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/content_width.dart';
import '../widgets/panel.dart';
import '../widgets/section_header.dart';

/// Melayani "tambah barang" (FR-B1) dan "ubah barang" (FR-B5), termasuk aksi
/// hapus (FR-B6) yang hanya muncul saat mengubah.
///
/// Sengaja digabung: bidangnya sama persis, dan layar detail terpisah hanya
/// akan menjadi rute ketiga menuju form yang sama.
class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, this.item});

  /// Null berarti mode tambah.
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

  /// Ada isian yang berbeda dari nilai awal. Dipakai untuk menahan tombol back
  /// supaya perubahan yang belum disimpan tidak hilang tanpa kabar.
  bool _dirty = false;

  /// Semua bidang yang dihitung sebagai perubahan.
  late final List<TextEditingController> _controllers = [
    _noUrut,
    _name,
    _code,
    _range,
    _brand,
    _pic,
    _status,
    _stockTotal,
  ];

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
    for (final controller in _controllers) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_markDirty);
      controller.dispose();
    }
    super.dispose();
  }

  /// Dipanggil setiap kali isi bidang berubah; hanya sekali per sesi yang
  /// membangun ulang layar, karena setelah itu nilainya sudah true.
  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final borrowed = item?.borrowed ?? 0;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Ubah Barang' : 'Tambah Barang'),
          flexibleSpace: appBarScrim(),
          actions: [
            if (widget.isEditing) ...[
              Tooltip(
                message: 'Hapus barang',
                child: Material(
                  color: AppTheme.chip,
                  shape: const CircleBorder(
                    side: BorderSide(color: AppTheme.outline),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _saving ? null : _delete,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: AppTheme.touch,
                      height: AppTheme.touch,
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
            ],
          ],
        ),
        bottomNavigationBar: _saveBar(),
        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ContentWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                AppTheme.spaceSm,
                AppTheme.spaceMd,
                AppTheme.spaceLg,
              ),
              children: [
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GroupLabel(
                        icon: Icons.badge_outlined,
                        label: 'Identitas alat',
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      TextFormField(
                        controller: _noUrut,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'No',
                          hintText: 'mis. 12',
                          prefixIcon: Icon(Icons.tag),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nama alat ukur *',
                          hintText: 'mis. Digital Caliper',
                          prefixIcon: Icon(Icons.straighten),
                        ),
                        validator: (value) =>
                            _requiredText(value, 'Nama alat ukur'),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      TextFormField(
                        controller: _code,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Kode alat ukur',
                          hintText: 'dipakai mencocokkan duplikat saat impor',
                          prefixIcon: Icon(Icons.qr_code_2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GroupLabel(
                        icon: Icons.tune,
                        label: 'Spesifikasi',
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      TextFormField(
                        controller: _range,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Range',
                          hintText: 'mis. 150 mm',
                          prefixIcon: Icon(Icons.speed),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      TextFormField(
                        controller: _brand,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Brand',
                          hintText: 'mis. Mitutoyo',
                          prefixIcon: Icon(Icons.sell_outlined),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      TextFormField(
                        controller: _pic,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'PIC',
                          hintText: 'penanggung jawab, mis. QC',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: AppTheme.space12),
                      TextFormField(
                        controller: _status,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          hintText: 'mis. OK atau Not Good / Rusak',
                          prefixIcon: Icon(Icons.toggle_on_outlined),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GroupLabel(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stok',
                      ),
                      const SizedBox(height: AppTheme.spaceMd),
                      TextFormField(
                        controller: _stockTotal,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Stok total *',
                          prefixIcon: const Icon(Icons.inventory),
                          helperText: widget.isEditing
                              ? '$borrowed unit sedang dipinjam. Nilai di '
                                  'bawah $borrowed akan ditolak.'
                              : 'Barang baru langsung tersedia sebanyak ini.',
                        ),
                        validator: _stockValidator,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tombol back Android: kalau ada isian yang belum disimpan, tanya dulu.
  Future<void> _confirmDiscard() async {
    final discard = await confirmAction(
      context,
      title: 'Buang perubahan?',
      message: 'Isian yang belum disimpan akan hilang.',
      confirmLabel: 'Buang',
    );
    if (!discard || !mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  /// Tombol simpan di bar bawah: selalu dalam jangkauan jempol, dan tidak ikut
  /// tergulir bersama bidang form.
  Widget _saveBar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.cardSolid,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_saving ? 'Menyimpan…' : 'Simpan'),
          ),
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
      // Saat menambah, barang langsung tersedia penuh. Saat mengubah,
      // repository menurunkan ketersediaan dari jumlah yang dipinjam, jadi
      // nilai ini bukan sumber kebenaran di sana.
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
      message: '"${item!.name}" akan dihapus. Penghapusan ditolak kalau barang '
          'masih terhubung ke peminjaman.',
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
