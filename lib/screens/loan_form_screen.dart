import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/item.dart';
import '../models/loan.dart';
import '../providers/item_provider.dart';
import '../providers/loan_provider.dart';
import '../widgets/empty_state.dart';

/// Serves both "catat peminjaman" (FR-L2) and "ubah peminjaman" (FR-L8).
class LoanFormScreen extends StatefulWidget {
  const LoanFormScreen({super.key, this.loan});

  /// Null means create mode.
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

  /// Items are read through the provider but never from the list screen's
  /// filtered copy, because a search left over from the Barang tab would hide
  /// the item that is about to be borrowed.
  late final Future<List<Item>> _items =
      context.read<ItemProvider>().allItems();

  int? _itemId;
  late DateTime _loanDate;
  late DateTime _dueDate;
  bool _saving = false;

  /// FR-L8: a finished loan keeps its item and quantity, so the form freezes
  /// them instead of letting the admin type something the repository rejects.
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
              action: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              ),
            );
          }
          return _form(items);
        },
      ),
    );
  }

  Widget _form(List<Item> items) {
    final theme = Theme.of(context);
    final selectedId = _itemId ?? items.first.id;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLocked) ...[
            _notice(
              'Peminjaman ini sudah selesai, jadi barang dan jumlahnya tidak '
              'bisa diubah lagi agar riwayat stok tetap benar.',
            ),
            const SizedBox(height: 16),
          ],
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Barang',
              border: OutlineInputBorder(),
              isDense: true,
              helperText: 'Angka dalam kurung adalah stok yang bisa dipinjam.',
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: items.any((item) => item.id == selectedId)
                    ? selectedId
                    : null,
                isExpanded: true,
                isDense: true,
                onChanged: _isLocked
                    ? null
                    : (value) => setState(() => _itemId = value),
                items: [
                  for (final item in items)
                    DropdownMenuItem<int>(
                      value: item.id,
                      child: Text(
                        '${item.name} (${_availableFor(item)} tersedia)',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _borrower,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Nama peminjam',
              helperText: 'Wajib. Contoh: Rani - XI RPL 1',
              border: OutlineInputBorder(),
            ),
            validator: (value) => _requiredText(value, 'Nama peminjam'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contact,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Kontak',
              helperText: 'Opsional. Nomor HP atau kelas.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _quantity,
            enabled: !_isLocked,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Jumlah pinjam',
              helperText: 'Wajib. Satu peminjaman hanya untuk satu jenis barang.',
              border: OutlineInputBorder(),
            ),
            validator: (value) => _quantityValidator(value, items),
          ),
          const SizedBox(height: 16),
          _dateTile(
            label: 'Tanggal pinjam',
            value: _loanDate,
            onTap: _pickLoanDate,
          ),
          const SizedBox(height: 16),
          _dateTile(
            label: 'Tanggal kembali rencana',
            value: _dueDate,
            onTap: _pickDueDate,
            helper: 'Melewati tanggal ini, status berubah jadi Terlambat.',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Catatan',
              helperText: 'Opsional. Contoh: untuk kegiatan class meeting.',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _submit(items),
            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
          const SizedBox(height: 8),
          Text(
            'Stok berkurang otomatis saat disimpan, dan kembali saat peminjaman '
            'ditandai selesai atau dihapus.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _notice(String message) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    String? helper,
  }) =>
      InkWell(
        onTap: _saving ? null : onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            helperText: helper,
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(formatDisplayDate(value)),
        ),
      );

  Item? _selectedItem(List<Item> items) {
    final id = _itemId ?? items.first.id;
    for (final item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// Units of this same loan are released before the new quantity is checked,
  /// which mirrors what the repository does inside its transaction.
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
    final item = _selectedItem(items);
    if (item == null) {
      return 'Pilih barang dulu.';
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
      // Keeping the due date after the loan date saves the admin one step and
      // avoids a pair of dates the repository would refuse.
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

  Future<void> _submit(List<Item> items) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final itemId = _itemId ?? items.first.id;
    if (itemId == null) {
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
      // A new loan always starts as borrowed; the repository enforces this too.
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
