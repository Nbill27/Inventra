import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/app_text.dart';
import '../core/exceptions.dart';
import '../core/formatters.dart';
import '../providers/item_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/settings_provider.dart';
import '../services/backup_service.dart';
import '../services/notification_gateway.dart';
import '../services/reminder_scheduler.dart';
import '../services/system_gateway.dart';
import '../widgets/app_background.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/content_width.dart';
import '../widgets/panel.dart';

/// Pengaturan app: pengingat pengembalian beserta peringatan bila Android
/// membatasi app, backup (buat, simpan ke luar, pulihkan), dan versi aplikasi.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool _permissionDenied = false;
  bool _batteryRestricted = false;
  String? _version;
  bool _restoring = false;
  bool _savingCopy = false;

  final _system = const SystemGateway();
  final _backup = BackupService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SettingsProvider>().load();
        _refreshPermission();
        _loadSystemInfo();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Izin notifikasi dan pengecualian baterai bisa diubah dari luar app, jadi
  /// keduanya dibaca ulang setiap layar ini kembali ke depan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermission();
      _loadSystemInfo();
    }
  }

  Future<void> _refreshPermission() async {
    final granted = await context.read<NotificationGateway>().hasPermission();
    if (mounted) {
      setState(() => _permissionDenied = !granted);
    }
  }

  Future<void> _loadSystemInfo() async {
    final version = await _system.appVersion();
    final ignoring = await _system.isIgnoringBatteryOptimizations();
    if (!mounted) {
      return;
    }
    setState(() {
      _version = version;
      // null berarti status tidak terbaca (platform tanpa kanal ini), dan
      // peringatan tidak ditampilkan supaya tidak menebak.
      _batteryRestricted = ignoring == false;
    });
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
                  if (_batteryRestricted) ...[
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'Android masih membatasi aplikasi ini di latar belakang, '
                      'jadi pengingat bisa tidak berbunyi. Kecualikan Inventra '
                      'dari optimasi baterai.',
                      style: AppText.bodySm.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _openBatterySettings,
                        icon: const Icon(Icons.battery_saver_outlined, size: 18),
                        label: const Text('Buka pengaturan baterai'),
                      ),
                    ),
                  ],
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
                  const SizedBox(height: AppTheme.spaceMd),
                  OutlinedButton.icon(
                    onPressed: settings.isBusy || _savingCopy ? null : _saveCopy,
                    icon: _savingCopy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share, size: 20),
                    label: Text(
                      _savingCopy ? 'Menyimpan…' : 'Simpan salinan ke…',
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  OutlinedButton.icon(
                    onPressed: settings.isBusy || _restoring ? null : _restore,
                    icon: _restoring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.restore, size: 20),
                    label: Text(
                      _restoring ? 'Memulihkan…' : 'Pulihkan dari berkas…',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              child: Text(
                'Berkas backup berisi seluruh data app: daftar barang, stok, '
                'dan riwayat peminjaman. Simpan salinannya ke luar app secara '
                'berkala — salinan di dalam app ikut terhapus bila aplikasi '
                'di-uninstall.',
                style: AppText.style(size: 12, color: AppTheme.muted),
              ),
            ),
            if (_version != null) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Center(
                child: Text(
                  'Inventra v$_version',
                  style: AppText.style(size: 12, color: AppTheme.muted),
                ),
              ),
            ],
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

  Future<void> _openBatterySettings() async {
    await _system.openBatterySettings();
    // Statusnya dibaca ulang saat layar kembali ke depan; lihat
    // didChangeAppLifecycleState.
  }

  Future<void> _saveCopy() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingCopy = true);
    try {
      final saved = await _backup.saveCopyToDevice();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Salinan disimpan. Simpan berkasnya di tempat aman.'
                : 'Penyimpanan dibatalkan.',
          ),
        ),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan salinan: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingCopy = false);
      }
    }
  }

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    // Provider dibaca sebelum ada await: setelah data berganti, objeknya tetap
    // sama, hanya isinya yang dimuat ulang.
    final items = context.read<ItemProvider>();
    final loans = context.read<LoanProvider>();
    final settings = context.read<SettingsProvider>();
    final reminders = context.read<ReminderScheduler>();

    final Uint8List? bytes;
    try {
      bytes = await _backup.pickBackupBytes();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal membaca berkas: $error')),
      );
      return;
    }
    if (bytes == null || !mounted) {
      return;
    }

    final confirmed = await confirmAction(
      context,
      title: 'Pulihkan data?',
      message: 'Seluruh barang, stok, dan riwayat peminjaman akan diganti '
          'dengan isi berkas backup. Data yang sekarang disalin dulu ke folder '
          'backup app sebelum diganti.',
      confirmLabel: 'Pulihkan',
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _restoring = true);
    try {
      final safety = await _backup.restoreFromBytes(bytes);
      // Seluruh isi database berganti, jadi semua pemegang salinan lama harus
      // memuat ulang — termasuk jadwal pengingat yang masih menunjuk pinjaman
      // dari data sebelumnya.
      await items.load();
      await loans.load();
      await settings.load();
      await reminders.sync(force: true);
      messenger.showSnackBar(
        SnackBar(content: Text('Data dipulihkan. Salinan data lama: $safety')),
      );
    } on AppException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal memulihkan data: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
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
