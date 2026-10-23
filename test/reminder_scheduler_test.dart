import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/db/database_helper.dart';
import 'package:peminjaman_barang/models/reminder.dart';
import 'package:peminjaman_barang/repositories/item_repository.dart';
import 'package:peminjaman_barang/repositories/loan_repository.dart';
import 'package:peminjaman_barang/services/notification_gateway.dart';
import 'package:peminjaman_barang/services/reminder_planner.dart';
import 'package:peminjaman_barang/services/reminder_scheduler.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import 'support/test_database.dart';

/// Gateway tiruan: mencatat apa yang akan dipasang ke sistem, tanpa plugin.
class FakeGateway implements NotificationGateway {
  FakeGateway({required this.now});

  DateTime now;
  final List<ReminderSlot> scheduled = [];
  int cancelCalls = 0;
  bool permission = true;

  @override
  DateTime nowInZone() => now;

  @override
  Future<void> initialize({void Function()? onTap}) async {}

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<int> pendingCount() async => scheduled.length;

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
    scheduled.clear();
  }

  @override
  Future<void> schedule(ReminderSlot slot) async => scheduled.add(slot);

  @override
  Future<void> showTest() async {}
}

void main() {
  late DatabaseHelper db;
  late ItemRepository items;
  late LoanRepository loans;
  late FakeGateway gateway;
  late ReminderScheduler scheduler;

  setUp(() async {
    db = createTestDatabase();
    items = ItemRepository(helper: db);
    loans = LoanRepository(helper: db);
    gateway = FakeGateway(now: DateTime(2026, 1, 15, 8));
    scheduler = ReminderScheduler(
      gateway: gateway,
      repository: loans,
      helper: db,
      // Horizon pendek supaya jumlah slot mudah diperiksa.
      planner: const ReminderPlanner(horizonDays: 2),
    );
  });

  tearDown(() => db.close());

  Future<int> buatPinjaman() async {
    final itemId = await items.create(itemFixture());
    return loans.create(
      loanFixture(
        itemId: itemId,
        loanDate: DateTime(2026, 1, 8),
        dueDate: DateTime(2026, 1, 15),
      ),
    );
  }

  test('memasang jadwal untuk pinjaman yang jatuh tempo', () async {
    await buatPinjaman();

    await scheduler.sync(force: true);

    expect(gateway.scheduled, hasLength(6));
    expect(gateway.scheduled.first.when, DateTime(2026, 1, 15, 9));
    expect(
      gateway.scheduled.first.title,
      '1 barang harus dikembalikan hari ini',
    );
  });

  test('penyelarasan kedua dilewati bila tidak ada yang berubah', () async {
    await buatPinjaman();
    await scheduler.sync(force: true);
    final cancelSetelahPertama = gateway.cancelCalls;

    await scheduler.sync();

    expect(gateway.cancelCalls, cancelSetelahPertama);
    expect(gateway.scheduled, hasLength(6));
  });

  test('barang dikembalikan menghapus seluruh pengingatnya', () async {
    final loanId = await buatPinjaman();
    await scheduler.sync(force: true);
    expect(gateway.scheduled, isNotEmpty);

    await loans.markReturned(
      loanId: loanId,
      returnDate: DateTime(2026, 1, 15),
    );
    await scheduler.sync();

    expect(gateway.scheduled, isEmpty);
  });

  test('pengingat yang dimatikan membatalkan semua jadwal', () async {
    await buatPinjaman();
    await scheduler.sync(force: true);
    final database = await db.database;
    await database.insert(
      'app_settings',
      {'key': ReminderKeys.enabled, 'value': '0'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await scheduler.sync(force: true);

    expect(gateway.scheduled, isEmpty);
  });

  test('alarm yang hilang dipasang ulang walau data tidak berubah', () async {
    await buatPinjaman();
    await scheduler.sync(force: true);
    // Meniru force stop: alarm hilang dari sistem tanpa mengubah database.
    gateway.scheduled.clear();

    await scheduler.sync();

    expect(gateway.scheduled, hasLength(6));
  });
}
