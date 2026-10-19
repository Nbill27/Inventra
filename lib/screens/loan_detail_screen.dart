import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_text.dart';
import '../core/app_theme.dart';
import '../core/dates.dart';
import '../core/formatters.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../providers/loan_provider.dart';
import '../widgets/app_background.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/content_width.dart';
import '../widgets/info_row.dart';
import '../widgets/loan_progress_card.dart';
import '../widgets/panel.dart';
import 'loan_form_screen.dart';

/// FR-L7: seluruh bidang satu peminjaman, plus aksi yang mengubah keadaannya.
///
/// Setelah perubahan, layar ini ditutup alih-alih digambar ulang, karena baris
/// yang membukanya adalah snapshot: daftar di belakang dimuat ulang provider
/// dan menampilkan nilai terbaru. Membatalkan form tidak menutup layar ini.
class LoanDetailScreen extends StatefulWidget {
  const LoanDetailScreen({super.key, required this.detail});

  final LoanDetail detail;

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  bool _busy = false;

  Future<void> _markReturned() async {
    final loan = widget.detail.loan;
    final item = widget.detail.item;
    final id = loan.id;
    if (id == null) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    // Barang hanya bisa dikembalikan antara tanggal pinjam dan hari ini, jadi
    // pemilih tanggal dipatok ke rentang itu alih-alih memercayai ketukan.
    final earliest = dateOnly(loan.loanDate);
    final today = dateOnly(DateTime.now());
    final latest = isBeforeDay(today, earliest) ? earliest : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: latest,
      firstDate: earliest,
      lastDate: latest,
      helpText: 'Tanggal barang dikembalikan',
    );
    if (picked == null || !mounted) {
      return;
    }

    // Pengaman kalau pemilih tanggal platform mengembalikan hari di luar rentang.
    if (isBeforeDay(picked, earliest)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tanggal kembali tidak boleh sebelum tanggal pinjam.'),
        ),
      );
      return;
    }
    if (isBeforeDay(latest, picked)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tanggal kembali tidak boleh melebihi hari ini.'),
        ),
      );
      return;
    }

    final returnDate = dateOnly(picked);
    final confirmed = await confirmAction(
      context,
      title: 'Tandai dikembalikan?',
      message:
          'Peminjaman ${loan.borrowerName} akan ditandai selesai pada '
          '${formatLongDate(returnDate)}. '
          '${loan.quantity} unit ${item.name} kembali ke stok.',
      confirmLabel: 'Ya, tandai',
      destructive: false,
    );
    if (!confirmed || !mounted) {
      return;
    }

    final provider = context.read<LoanProvider>();
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    final error =
        await provider.markReturned(loanId: id, returnDate: returnDate);

    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Peminjaman selesai, stok sudah dikembalikan.'),
      ),
    );
  }

  Future<void> _edit() async {
    // Form mengembalikan true hanya kalau simpan berhasil. Saat dibatalkan,
    // layar detail tetap terbuka seperti yang diharapkan admin.
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LoanFormScreen(loan: widget.detail.loan),
      ),
    );
    if (!mounted || saved != true) {
      return;
    }
    // Simpan berhasil: daftar di belakang sudah dimuat ulang provider,
    // sedangkan snapshot di layar ini sudah basi, jadi detail ditutup.
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final loan = widget.detail.loan;
    final id = loan.id;
    if (id == null) {
      return;
    }

    final returnsStock = loan.status == LoanStatus.borrowed;
    final confirmed = await confirmAction(
      context,
      title: 'Hapus peminjaman?',
      message: returnsStock
          ? 'Peminjaman ${loan.borrowerName} akan dihapus dan '
              '${loan.quantity} unit ${widget.detail.item.name} kembali ke stok.'
          : 'Peminjaman ${loan.borrowerName} akan dihapus dari riwayat. Stok '
              'tidak berubah karena barangnya sudah dikembalikan.',
      confirmLabel: 'Hapus',
    );
    if (!confirmed || !mounted) {
      return;
    }

    final provider = context.read<LoanProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _busy = true);
    final error = await provider.delete(id);

    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Peminjaman dihapus.')));
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.detail.loan;
    final item = widget.detail.item;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Peminjaman'),
        flexibleSpace: appBarScrim(),
        actions: [
          _RoundAction(
            tooltip: 'Ubah peminjaman',
            icon: Icons.edit_outlined,
            color: AppTheme.onPrimaryContainer,
            onTap: _busy ? null : _edit,
          ),
          _RoundAction(
            tooltip: 'Hapus peminjaman',
            icon: Icons.delete_outline,
            color: AppTheme.error,
            onTap: _busy ? null : _delete,
          ),
          const SizedBox(width: AppTheme.spaceSm),
        ],
      ),
      bottomNavigationBar: loan.status == LoanStatus.borrowed
          ? _returnBar()
          : null,
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMd,
            AppTheme.spaceSm,
            AppTheme.spaceMd,
            AppTheme.spaceLg,
          ),
          children: [
            Panel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.borrowerName,
                      style: AppText.headlineMd.copyWith(color: AppTheme.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text(
                    '${loan.quantity} unit',
                    style: AppText.style(
                      size: 20,
                      weight: 700,
                      color: AppTheme.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            LoanProgressCard(detail: widget.detail),
            const SizedBox(height: AppTheme.spaceMd),
            Panel(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
              ),
              child: Column(
                children: [
                  InfoRow(
                    label: 'Barang',
                    value: _itemLabel(item.name, item.code),
                  ),
                  InfoRow(label: 'Jumlah', value: '${loan.quantity} unit'),
                  InfoRow(label: 'Kontak', value: loan.contact),
                  InfoRow(
                    label: 'Tanggal pinjam',
                    value: formatLongDate(loan.loanDate),
                  ),
                  InfoRow(
                    label: 'Rencana kembali',
                    value: formatLongDate(loan.dueDate),
                  ),
                  if (loan.returnDate != null)
                    InfoRow(
                      label: 'Dikembalikan',
                      value: formatLongDate(loan.returnDate!),
                    ),
                  InfoRow(
                    label: 'Catatan',
                    value: loan.note,
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Aksi utama layar: selalu terlihat dan dalam jangkauan jempol.
  ///
  /// Peminjaman yang tanggal pinjamnya masih di depan belum bisa dikembalikan:
  /// repository menolak tanggal kembali di masa depan, jadi tombolnya dimatikan
  /// dengan alasan yang terbaca alih-alih membiarkan admin menekan lalu gagal.
  Widget _returnBar() {
    final notStarted = isBeforeDay(
      dateOnly(DateTime.now()),
      dateOnly(widget.detail.loan.loanDate),
    );
    final button = FilledButton.icon(
      onPressed: (_busy || notStarted) ? null : _markReturned,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.deep,
      ),
      icon: const Icon(Icons.assignment_turned_in_outlined, size: 20),
      label: Text(
        notStarted ? 'Belum bisa dikembalikan' : 'Tandai dikembalikan',
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.cardSolid,
        border: Border(top: BorderSide(color: AppTheme.outlineVariant)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          // Tooltip hanya saat tombol mati: tombol nonaktif tidak bisa dibaca
          // alasannya oleh pembaca layar, jadi sebabnya ditempel di sini.
          child: notStarted
              ? Tooltip(message: 'Tanggal pinjam belum tiba.', child: button)
              : button,
        ),
      ),
    );
  }

  static String _itemLabel(String name, String? code) =>
      code == null ? name : '$name ($code)';
}

/// Tombol ikon bulat untuk bar judul layar detail.
class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.space6),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: AppTheme.chip,
          shape: const CircleBorder(
            side: BorderSide(color: AppTheme.outline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: AppTheme.touch,
              height: AppTheme.touch,
              child: Icon(
                icon,
                size: 20,
                color: onTap == null ? AppTheme.outlineVariant : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
