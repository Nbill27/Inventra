import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../db/database_helper.dart';
import '../models/loan_filter.dart';
import '../repositories/loan_repository.dart';
import 'notification_gateway.dart';
import 'reminder_planner.dart';

/// Kunci `app_settings` yang dipakai fitur pengingat.
class ReminderKeys {
  /// '1' bila pengingat aktif. Tidak ada baris berarti aktif.
  static const enabled = 'notif_enabled';

  /// Pernah menawarkan izin notifikasi? Supaya dialognya tidak muncul lagi.
  static const prompted = 'notif_prompted';

  /// Sidik jari rencana terakhir yang sudah dipasang ke sistem.
  static const signature = 'reminder_signature';
}

/// Kontrak minimal yang dibutuhkan [LoanProvider]: menyusun ulang jadwal.
abstract class ReminderSync {
  Future<void> sync({bool force = false});
}

/// Menjaga agar alarm di sistem selalu sama dengan data peminjaman.
///
/// Dipanggil saat app dibuka, saat app kembali ke depan, dan setelah setiap
/// perubahan data. Perhitungan teksnya ada di [ReminderPlanner]; kelas ini
/// hanya memutuskan kapan membatalkan dan memasang ulang.
class ReminderScheduler implements ReminderSync {
  ReminderScheduler({
    required this.gateway,
    LoanRepository? repository,
    DatabaseHelper? helper,
    ReminderPlanner? planner,
  })  : _repository = repository ?? LoanRepository(),
        _helper = helper ?? DatabaseHelper.instance,
        _planner = planner ?? const ReminderPlanner();

  final NotificationGateway gateway;
  final LoanRepository _repository;
  final DatabaseHelper _helper;
  final ReminderPlanner _planner;

  /// Dinaikkan setiap kali pengguna mengetuk notifikasi pengingat. Layar
  /// mendengarkannya untuk membuka daftar peminjaman.
  final ValueNotifier<int> taps = ValueNotifier(0);

  bool _running = false;
  bool _pending = false;
  bool _pendingForce = false;

  /// Menyiapkan gateway sekali di awal, sekaligus menyambungkan ketukan
  /// notifikasi ke [taps].
  Future<void> initialize() async {
    await gateway.initialize(onTap: () => taps.value++);
  }

  /// Menyamakan jadwal di sistem dengan data saat ini.
  ///
  /// Bila dipanggil saat penyelarasan lain masih berjalan, permintaan digabung
  /// menjadi satu putaran tambahan — dua proses yang tumpang tindih bisa saling
  /// menghapus alarm.
  @override
  Future<void> sync({bool force = false}) async {
    if (_running) {
      _pending = true;
      _pendingForce = _pendingForce || force;
      return;
    }
    _running = true;
    try {
      var runForce = force;
      do {
        _pending = false;
        await _run(force: runForce);
        runForce = _pendingForce;
        _pendingForce = false;
      } while (_pending);
    } finally {
      _running = false;
    }
  }

  Future<void> _run({required bool force}) async {
    try {
      // Aman dipanggil berkali-kali; gateway mengingat status inisialisasinya.
      await gateway.initialize(onTap: () => taps.value++);

      if (!await _notificationsEnabled()) {
        await gateway.cancelAll();
        await _saveSignature('');
        return;
      }

      final loans = await _repository.getAllDetailed(
        filter: LoanFilter.borrowed,
      );
      final plan = _planner.build(
        loans: loans,
        now: _wallClock(gateway.nowInZone()),
      );

      if (!force) {
        final stored = await _readSetting(ReminderKeys.signature) ?? '';
        // Jumlah alarm ikut dicek: setelah HP restart atau force stop, alarm
        // bisa hilang walau datanya tidak berubah.
        if (stored == plan.signature &&
            await gateway.pendingCount() == plan.slots.length) {
          return;
        }
      }

      await gateway.cancelAll();
      for (final slot in plan.slots) {
        await gateway.schedule(slot);
      }
      await _saveSignature(plan.signature);
    } catch (error, stackTrace) {
      // Pengingat tidak boleh menjatuhkan alur utama aplikasi.
      debugPrint('Gagal menyelaraskan pengingat: $error\n$stackTrace');
    }
  }

  /// Membuang informasi zona waktu.
  ///
  /// Perbandingan `DateTime` lintas zona memakai waktu absolut, bukan jam
  /// dinding. Planner bekerja dengan jam dinding WIB, jadi "sekarang" harus
  /// diubah ke bentuk yang sama sebelum dibandingkan dengan slot.
  DateTime _wallClock(DateTime value) => DateTime(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      );

  Future<bool> _notificationsEnabled() async =>
      (await _readSetting(ReminderKeys.enabled) ?? '1') == '1';

  Future<String?> _readSetting(String key) async {
    final db = await _helper.database;
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _saveSignature(String value) async {
    final db = await _helper.database;
    await db.insert(
      'app_settings',
      {'key': ReminderKeys.signature, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
