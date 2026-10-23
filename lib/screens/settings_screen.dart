import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/app_text.dart';
import '../core/formatters.dart';
import '../providers/settings_provider.dart';
import '../services/notification_gateway.dart';
import '../services/reminder_scheduler.dart';
import '../widgets/app_background.dart';
import '../widgets/content_width.dart';
import '../widgets/panel.dart';

/// Pengaturan app: pengingat pengembalian, backup otomatis bulanan dengan
/// saklarnya, tombol backup manual, dan keterangan kapan backup terakhir
/// dijalankan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SettingsProvider>().load();
        _refreshPermission();
      }
    });
  }

  Future<void> _refreshPermission() async {
    final granted = await context.read<NotificationGateway>().hasPermission();
    if (mounted) {
      setState(() => _permissionDenied = !granted);
    }
  }

  /// Menampilkan notifikasi sekarang juga, supaya pengingat bisa diuji tanpa
  /// menunggu slot 09.00/13.00/15.00.
  Future<void> _sendTestNotification() async {
    final messenger = ScaffoldMessenger.of(context);
    final gateway = context.read<NotificationGateway>();
    try {
      await gateway.showTest();
      if (mounted) {
        await _refreshPermission();
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Notifikasi uji dikirim.')),
      );
    } catch (error) {
      // Berbeda dengan penjadwalan, kegagalan di sini harus terlihat: tombol
      // ini justru dipakai untuk mencari tahu kenapa pengingat tidak muncul.
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal mengirim notifikasi uji: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        flexibleSpace: appBarScrim(),
      ),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_active_outlined,
                        size: 20,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          'Pengingat pengembalian',
                          style: AppText.style(
                            size: 15,
                            weight: 600,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      Switch(
                        value: settings.notificationsEnabled,
                        onChanged: _toggleReminders,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'Notifikasi dikirim pukul 09.00, 13.00, dan 15.00 setiap '
                    'hari sampai barang ditandai dikembalikan.',
                    style: AppText.bodySm.copyWith(color: AppTheme.muted),
                  ),
                  if (_permissionDenied) ...[
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'Izin notifikasi dimatikan di pengaturan Android, jadi '
                      'pengingat tidak akan muncul.',
                      style: AppText.bodySm.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppTheme.spaceXs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _sendTestNotification,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      label: const Text('Kirim notifikasi uji'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.backup_outlined,
                        size: 20,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          'Backup otomatis bulanan',
                          style: AppText.style(
                            size: 15,
                            weight: 600,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      Switch(
                        value: settings.autoBackup,
                        onChanged: settings.isBusy
                            ? null
                            : (value) => _toggleAuto(value),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    'Bila nyala, salinan data dibuat otomatis sebulan sekali '
                    'saat app dibuka. Bila mati, backup hanya lewat tombol di '
                    'bawah.',
                    style: AppText.bodySm.copyWith(color: AppTheme.muted),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  FilledButton.icon(
                    onPressed: settings.isBusy ? null : _backupNow,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.deep,
                    ),
                    icon: settings.isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 20),
                    label: Text(
                      settings.isBusy ? 'Menyalin data…' : 'Backup sekarang',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(
                    _lastBackupText(settings),
                    style: AppText.bodySm.copyWith(color: AppTheme.muted),
                  ),
                  if (settings.lastBackupPath != null) ...[
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      'Berkas: ${settings.lastBackupPath}',
                      style: AppText.style(
                        size: 11.5,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              child: Text(
                'Berkas backup berisi seluruh data app: daftar barang, stok, '
                'dan riwayat peminjaman.',
                style: AppText.style(size: 12, color: AppTheme.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastBackupText(SettingsProvider settings) {
    final last = settings.lastBackupAt;
    if (last == null) {
      return 'Belum pernah backup.';
    }
    final next = last.add(SettingsProvider.monthlyInterval);
    return 'Backup terakhir: ${formatLongDate(last)}, '
        '${DateFormat('HH:mm').format(last)}. '
        'Backup berikutnya: sekitar ${formatLongDate(next)}.';
  }

  Future<void> _toggleReminders(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final settings = context.read<SettingsProvider>();
    final reminders = context.read<ReminderScheduler>();
    final gateway = context.read<NotificationGateway>();

    final error = await settings.setNotificationsEnabled(value);
    if (value && error == null) {
      final granted = await gateway.requestPermission();
      if (mounted) {
        setState(() => _permissionDenied = !granted);
      }
    }
    // Menyalakan pengingat langsung memasang jadwal; mematikannya membatalkan
    // semua alarm yang tersisa.
    await reminders.sync(force: true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (value
                  ? 'Pengingat pengembalian dinyalakan.'
                  : 'Pengingat pengembalian dimatikan.'),
        ),
      ),
    );
  }

  Future<void> _toggleAuto(bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<SettingsProvider>().setAutoBackup(value);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (value
                  ? 'Backup otomatis bulanan dinyalakan.'
                  : 'Backup otomatis dimatikan.'),
        ),
      ),
    );
  }

  Future<void> _backupNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<SettingsProvider>().backupNow();
    messenger.showSnackBar(
      SnackBar(
        content: Text(error ?? 'Backup selesai. Berkas tersimpan di folder '
            'backup app.'),
      ),
    );
  }
}
