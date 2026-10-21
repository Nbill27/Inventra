import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../db/database_helper.dart';
import '../services/backup_service.dart';
import '../services/reminder_scheduler.dart';

/// Pengaturan app yang tersimpan di tabel `app_settings`: saklar backup
/// otomatis, waktu backup terakhir, dan saklar pengingat pengembalian.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({BackupService? backupService, DatabaseHelper? helper})
      : _backupService = backupService ?? BackupService(),
        _helper = helper ?? DatabaseHelper.instance;

  static const _keyAutoBackup = 'backup_auto';
  static const _keyLastBackup = 'last_backup_at';

  /// Backup otomatis dianggap jatuh tempo setelah sekian hari.
  static const monthlyInterval = Duration(days: 30);

  final BackupService _backupService;
  final DatabaseHelper _helper;

  bool _autoBackup = false;
  DateTime? _lastBackupAt;
  bool _busy = false;
  String? _lastBackupPath;
  bool _notificationsEnabled = true;
  bool _notificationsPrompted = false;

  bool get autoBackup => _autoBackup;
  DateTime? get lastBackupAt => _lastBackupAt;
  bool get isBusy => _busy;
  String? get lastBackupPath => _lastBackupPath;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get notificationsPrompted => _notificationsPrompted;

  Future<void> load() async {
    final db = await _helper.database;
    final rows = await db.query(
      'app_settings',
      where: 'key IN (?, ?, ?, ?)',
      whereArgs: [
        _keyAutoBackup,
        _keyLastBackup,
        ReminderKeys.enabled,
        ReminderKeys.prompted,
      ],
    );
    for (final row in rows) {
      final value = row['value'] as String;
      switch (row['key'] as String) {
        case _keyAutoBackup:
          _autoBackup = value == '1';
        case _keyLastBackup:
          _lastBackupAt = DateTime.tryParse(value)?.toLocal();
        case ReminderKeys.enabled:
          _notificationsEnabled = value == '1';
        case ReminderKeys.prompted:
          _notificationsPrompted = value == '1';
      }
    }
    notifyListeners();
  }

  /// Menyalakan atau mematikan backup otomatis. Kembaliannya: pesan galat,
  /// atau null bila berhasil.
  Future<String?> setAutoBackup(bool enabled) async {
    final previous = _autoBackup;
    _autoBackup = enabled;
    notifyListeners();
    try {
      final db = await _helper.database;
      await db.insert(
        'app_settings',
        {'key': _keyAutoBackup, 'value': enabled ? '1' : '0'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return null;
    } catch (error) {
      _autoBackup = previous;
      notifyListeners();
      return 'Gagal menyimpan pengaturan: $error';
    }
  }

  /// Menyalakan atau mematikan pengingat pengembalian. Kembaliannya: pesan
  /// galat, atau null bila berhasil.
  Future<String?> setNotificationsEnabled(bool enabled) async {
    final previous = _notificationsEnabled;
    _notificationsEnabled = enabled;
    notifyListeners();
    try {
      await _writeSetting(ReminderKeys.enabled, enabled ? '1' : '0');
      return null;
    } catch (error) {
      _notificationsEnabled = previous;
      notifyListeners();
      return 'Gagal menyimpan pengaturan: $error';
    }
  }

  /// Menandai bahwa tawaran izin notifikasi sudah pernah muncul.
  Future<void> markNotificationsPrompted() async {
    _notificationsPrompted = true;
    notifyListeners();
    try {
      await _writeSetting(ReminderKeys.prompted, '1');
    } catch (error) {
      debugPrint('Gagal menyimpan status tawaran notifikasi: $error');
    }
  }

  Future<void> _writeSetting(String key, String value) async {
    final db = await _helper.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Backup manual dari layar Pengaturan. Kembaliannya pesan galat, atau null
  /// bila berhasil.
  Future<String?> backupNow() async {
    if (_busy) {
      return null;
    }
    _busy = true;
    notifyListeners();
    try {
      _lastBackupPath = await _backupService.runBackup();
      await _saveLastBackup(DateTime.now());
      return null;
    } catch (error) {
      return 'Backup gagal: $error';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Dipanggil saat app dibuka. Backup berjalan hanya bila saklarnya nyala
  /// dan backup terakhir sudah lebih tua dari satu bulan; selain itu tidak
  /// ada kerja sama sekali.
  Future<void> maybeRunMonthlyBackup() async {
    if (!_autoBackup || _busy) {
      return;
    }
    final last = _lastBackupAt;
    if (last != null && DateTime.now().difference(last) < monthlyInterval) {
      return;
    }
    await backupNow();
  }

  Future<void> _saveLastBackup(DateTime when) async {
    _lastBackupAt = when;
    notifyListeners();
    final db = await _helper.database;
    await db.insert(
      'app_settings',
      {'key': _keyLastBackup, 'value': when.toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
