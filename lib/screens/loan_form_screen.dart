import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/item.dart';
import '../models/loan.dart';
import '../providers/item_provider.dart';
import '../providers/loan_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/content_width.dart';
import '../widgets/empty_state.dart';
import '../widgets/item_picker_sheet.dart';
import '../widgets/panel.dart';
import '../widgets/section_header.dart';

/// Melayani "catat peminjaman" (FR-L2) dan "ubah peminjaman" (FR-L8).
class LoanFormScreen extends StatefulWidget {
  const LoanFormScreen({super.key, this.loan});

  /// Null berarti mode tambah.
  final Loan? loan;

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _borrower;
  late final TextEditingController _contact;
  late final TextEditingController _quantity;
  late final TextEditingController _note;

  /// Barang dibaca lewat provider, bukan dari salinan yang sudah difilter layar
  /// daftar: pencarian yang tersisa di tab Barang bisa menyembunyikan barang
  /// yang justru mau dipinjam.
  late final Future<List<Item>> _items =
      context.read<ItemProvider>().allItems();

  int? _itemId;
  late DateTime _loanDate;
  late DateTime _dueDate;
  bool _saving = false;

  /// Barang tidak dipilih otomatis. Dengan daftar yang bisa berisi puluhan ribu
  /// baris, menebak satu baris pertama justru berisiko salah catat.
  bool _itemError = false;

  /// FR-L8: peminjaman yang sudah selesai menyimpan barang dan jumlahnya, jadi
  /// form membekukan keduanya alih-alih membiarkan admin mengetik nilai yang
  /// akan ditolak repository.
  bool get _isLocked => widget.loan?.status == LoanStatus.returned;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;
    final today = dateOnly(DateTime.now());
    _borrower = TextEditingController(text: loan?.borrowerName ?? '');
    _contact = TextEditingController(text: loan?.contact ?? '');
    _quantity = TextEditingController(text: loan?.quantity.toString() ?? '1');
    _note = TextEditingController(text: loan?.note ?? '');
    _itemId = loan?.itemId;
    _loanDate = loan?.loanDate ?? today;
    _dueDate = loan?.dueDate ?? today.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _borrower.dispose();
    _contact.dispose();
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.loan == null ? 'Tambah Peminjaman' : 'Ubah Peminjaman',
        ),
        flexibleSpace: appBarScrim(),
      ),
      bottomNavigationBar: FutureBuilder<List<Item>>(
        future: _items,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Item>[];
          if (snapshot.connectionState != ConnectionState.done ||
              items.isEmpty) {
            return const SizedBox.shrink();
          }
          return _saveBar();
        },
      ),
      body: FutureBuilder<List<Item>>(
        future: _items,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <Item>[];
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'Belum ada barang',
              message: 'Tambahkan barang dulu di tab Barang, baru peminjaman '
                  'bisa dicatat.',
              actions: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Kembali'),
                ),
              ],
            );
          }
          return _form(items);
        },
      ),
    );
  }

  Widget _form(List<Item> items) {
    return Form(
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
            if (_isLocked) ...[
              _notice(
                'Peminjaman ini sudah selesai, jadi barang dan jumlahnya tidak '
                'bisa diubah lagi agar riwayat stok tetap benar.',
              ),
              const SizedBox(height: AppTheme.spaceMd),
            ],

            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GroupLabel(
                    icon: Icons.person_outline,
                    label: 'Barang & peminjam',
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  _itemField(items),
                  const SizedBox(height: AppTheme.space12),
                  TextFormField(
                    controller: _borrower,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nama peminjam *',
                      hintText: 'mis. Rani - XI RPL 1',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => _requiredText(value, 'Nama peminjam'),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  TextFormField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Kontak',
                      hintText: 'nomor HP atau kelas',
                      prefixIcon: Icon(Icons.phone_outlined),
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
                    icon: Icons.event_outlined,
                    label: 'Jumlah & tanggal',
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  TextFormField(
                    controller: _quantity,
                    enabled: !_isLocked,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah pinjam *',
                      prefixIcon: Icon(Icons.numbers),
                      helperText:
                          'Satu peminjaman hanya untuk satu jenis barang.',
                    ),
                    validator: (value) => _quantityValidator(value, items),
                  ),
                  const SizedBox(height: AppTheme.space12),
                  _dateTile(
                    label: 'Tanggal pinjam',
                    value: _loanDate,
                    onTap: _pickLoanDate,
                  ),
                  const SizedBox(height: AppTheme.space12),
                  _dateTile(
                    label: 'Tanggal kembali rencana',
                    value: _dueDate,
                    onTap: _pickDueDate,
                    helper:
                        'Melewati tanggal ini, status berubah jadi Terlambat.',
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
                    icon: Icons.notes_outlined,
                    label: 'Catatan',
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  TextFormField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Catatan',
                      hintText: 'mis. untuk kegiatan class meeting',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Tombol simpan di bar bawah, tetap dalam jangkauan jempol.
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

  /// Bidang barang berupa tombol yang membuka pemilih, bukan dropdown.
  ///
  /// Dropdown membangun seluruh isi daftar sekaligus, jadi daftar yang panjang
  /// membuat layar berat dan pengguna tetap harus menggulir untuk menemukan
  /// satu nama. Di pemilih, barang disaring dulu lewat pencarian.
  Widget _itemField(List<Item> items) {
    final selected = _selectedItem(items);
    final label = selected == null
        ? 'Belum dipilih'
        : '${selected.name} · ${_availableFor(selected)} tersedia';

    return InkWell(
      onTap: _isLocked ? null : () => _pickItem(items),
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Barang *',
          prefixIcon: const Icon(Icons.inventory_2_outlined),
          suffixIcon: Icon(
            _isLocked ? Icons.lock_outline : Icons.unfold_more,
          ),
          helperText: 'Cari lalu pilih barang yang dipinjam.',
          errorText: _itemError ? 'Barang wajib dipilih.' : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.style(
            size: 14,
            weight: 500,
            color: selected == null ? AppTheme.muted : AppTheme.ink,
          ),
        ),
      ),
    );
  }

  Future<void> _pickItem(List<Item> items) async {
    final picked = await showItemPicker(
      context,
      items: items,
      selectedId: _itemId,
      availableFor: _availableFor,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _itemId = picked;
      _itemError = false;
    });
  }

  Widget _notice(String message) {
    return Panel(
      fill: AppTheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.onSurfaceVariant),
          const SizedBox(width: AppTheme.space12),
          Expanded(
            child: Text(
              message,
              style: AppText.bodyMd.copyWith(color: AppTheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  /// Bidang baca-saja yang membuka pemilih tanggal, supaya bentuknya sama
  /// dengan input lain di form, bukan baris teks polos.
  Widget _dateTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    String? helper,
  }) =>
      InkWell(
        onTap: _saving ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            prefixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(
            formatDisplayDate(value),
            style: AppText.style(size: 14, weight: 500, color: AppTheme.ink),
          ),
        ),
      );

  Item? _selectedItem(List<Item> items) {
    final id = _itemId;
    if (id == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// Unit dari peminjaman ini dilepas lebih dulu sebelum jumlah baru diperiksa,
  /// sama seperti yang dilakukan repository di dalam transaksinya.
  int _availableFor(Item item) {
    final existing = widget.loan;
    final own = existing != null &&
            existing.itemId == item.id &&
            existing.status == LoanStatus.borrowed
        ? existing.quantity
        : 0;
    return item.stockAvailable + own;
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

  String? _quantityValidator(String? value, List<Item> items) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Jumlah pinjam wajib diisi.';
    }
    final parsed = int.tryParse(text);
    if (parsed == null) {
      return 'Jumlah pinjam harus angka bulat.';
    }
    if (parsed < 1) {
      return 'Jumlah pinjam minimal 1.';
    }
    if (_isLocked) {
      return null;
    }
    // Barang belum dipilih: kesalahannya ditampilkan di bidang barang, bukan
    // di sini, supaya pesannya tidak muncul dua kali.
    final item = _selectedItem(items);
    if (item == null) {
      return null;
    }
    final available = _availableFor(item);
    if (parsed > available) {
      return 'Stok ${item.name} tersedia hanya $available.';
    }
    return null;
  }

  Future<void> _pickLoanDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _loanDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal pinjam',
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _loanDate = dateOnly(picked);
      // Menjaga tanggal kembali tetap setelah tanggal pinjam menghemat satu
      // langkah admin dan menghindari pasangan tanggal yang ditolak repository.
      if (isBeforeDay(_dueDate, _loanDate)) {
        _dueDate = _loanDate;
      }
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isBeforeDay(_dueDate, _loanDate) ? _loanDate : _dueDate,
      firstDate: _loanDate,
      lastDate: DateTime(2100),
      helpText: 'Pilih rencana tanggal kembali',
    );
    if (picked == null) {
      return;
    }
    setState(() => _dueDate = dateOnly(picked));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final itemId = _itemId;
    if (itemId == null) {
      setState(() => _itemError = true);
      return;
    }

    final provider = context.read<LoanProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final existing = widget.loan;

    setState(() => _saving = true);

    final draft = Loan(
      id: existing?.id,
      itemId: itemId,
      borrowerName: _borrower.text,
      contact: _contact.text,
      quantity: int.parse(_quantity.text.trim()),
      loanDate: _loanDate,
      dueDate: _dueDate,
      returnDate: existing?.returnDate,
      // Peminjaman baru selalu mulai sebagai dipinjam; repository juga menegakkan.
      status: existing?.status ?? LoanStatus.borrowed,
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
          existing == null ? 'Peminjaman dicatat.' : 'Perubahan disimpan.',
        ),
      ),
    );
  }
}
