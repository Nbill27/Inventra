import 'package:flutter_test/flutter_test.dart';
import 'package:peminjaman_barang/models/item.dart';
import 'package:peminjaman_barang/models/loan.dart';
import 'package:peminjaman_barang/models/loan_detail.dart';
import 'package:peminjaman_barang/services/reminder_planner.dart';

/// Satu peminjaman siap pakai. `due` adalah tanggal tenggat, dan tanggal
/// pinjam selalu seminggu sebelumnya.
LoanDetail detail({
  int id = 1,
  String item = 'Proyektor',
  String borrower = 'Budi',
  int quantity = 1,
  required DateTime due,
  LoanStatus status = LoanStatus.borrowed,
}) =>
    LoanDetail(
      loan: Loan(
        id: id,
        itemId: id,
        borrowerName: borrower,
        quantity: quantity,
        loanDate: due.subtract(const Duration(days: 7)),
        dueDate: due,
        status: status,
      ),
      item: Item(id: id, name: item, stockTotal: 5, stockAvailable: 5),
    );

void main() {
  // Pukul 08.00 WIB: ketiga slot hari itu masih di depan.
  final pagi = DateTime(2026, 10, 21, 8);

  group('hari tenggat', () {
    test('tiga slot dikirim pada hari yang sama', () {
      final plan = ReminderPlanner(horizonDays: 1).build(
        loans: [detail(due: DateTime(2026, 10, 21))],
        now: pagi,
      );

      expect(plan.slots.map((slot) => slot.when.hour), [9, 13, 15]);
      expect(
        plan.slots.first.title,
        '1 barang harus dikembalikan hari ini',
      );
      expect(plan.slots.first.entries.single.isDueToday, isTrue);
    });

    test('slot yang jamnya sudah lewat tidak dijadwalkan', () {
      final plan = ReminderPlanner(horizonDays: 1).build(
        loans: [detail(due: DateTime(2026, 10, 21))],
        now: DateTime(2026, 10, 21, 14),
      );

      expect(plan.slots.map((slot) => slot.when.hour), [15]);
    });

    test('hari tanpa barang jatuh tempo tidak menghasilkan slot', () {
      final plan = ReminderPlanner(horizonDays: 1).build(
        loans: [detail(due: DateTime(2026, 10, 25))],
        now: pagi,
      );

      expect(plan.isEmpty, isTrue);
    });
  });

  group('keterlambatan', () {
    test('jumlah hari terlambat dihitung dari tanggal slot', () {
      final plan = ReminderPlanner(horizonDays: 3).build(
        loans: [detail(due: DateTime(2026, 10, 20))],
        now: pagi,
      );

      final besok = plan.slots.firstWhere(
        (slot) => slot.when.day == 22 && slot.when.hour == 9,
      );
      expect(besok.title, 'Terlambat 2 hari');
      expect(besok.detail, contains('terlambat 2 hari'));
    });

    test('pengingat berlanjut setiap hari sampai ujung horizon', () {
      final plan = ReminderPlanner(horizonDays: 30).build(
        loans: [detail(due: DateTime(2026, 10, 20))],
        now: pagi,
      );

      // 30 hari x 3 jam, semuanya berisi karena barang tetap terlambat.
      expect(plan.slots, hasLength(90));
    });

    test('barang yang sudah dikembalikan tidak pernah masuk', () {
      final plan = ReminderPlanner(horizonDays: 5).build(
        loans: [
          detail(due: DateTime(2026, 10, 21), status: LoanStatus.returned),
        ],
        now: pagi,
      );

      expect(plan.isEmpty, isTrue);
    });
  });

  group('isi notifikasi', () {
    test('sepuluh barang jatuh tempo tetap satu notifikasi per jam', () {
      final loans = List.generate(
        10,
        (index) => detail(
          id: index + 1,
          item: 'Alat ${String.fromCharCode(65 + index)}',
          borrower: 'Peminjam ${index + 1}',
          due: DateTime(2026, 10, 21),
        ),
      );

      final plan = ReminderPlanner(horizonDays: 1).build(loans: loans, now: pagi);

      expect(plan.slots, hasLength(3));
      final slot = plan.slots.first;
      expect(slot.title, '10 barang harus dikembalikan hari ini');
      expect(slot.entries, hasLength(10));
      // Hanya lima baris pertama yang ditulis, sisanya diringkas.
      expect(slot.detail, contains('• Alat A'));
      expect(slot.detail, contains('• Alat E'));
      expect(slot.detail, isNot(contains('• Alat F')));
      expect(slot.detail, contains('… dan 5 barang lainnya'));
    });

    test('campuran jatuh tempo dan terlambat disebut di judul', () {
      final plan = ReminderPlanner(horizonDays: 1).build(
        loans: [
          detail(id: 1, item: 'Mikroskop', due: DateTime(2026, 10, 21)),
          detail(id: 2, item: 'Kamera', due: DateTime(2026, 10, 21)),
          detail(id: 3, item: 'Tripod', due: DateTime(2026, 10, 19)),
        ],
        now: pagi,
      );

      final slot = plan.slots.first;
      expect(slot.title, '2 harus kembali hari ini · 1 terlambat');
      // Barang yang jatuh tempo hari ini ditulis lebih dulu.
      expect(slot.entries.first.itemName, 'Kamera');
      expect(slot.entries.last.itemName, 'Tripod');
      expect(slot.entries.last.daysLate, 2);
    });

    test('ringkasan satu baris dibatasi empat nama', () {
      final loans = List.generate(
        6,
        (index) => detail(
          id: index + 1,
          item: 'Alat ${index + 1}',
          due: DateTime(2026, 10, 21),
        ),
      );

      final plan = ReminderPlanner(horizonDays: 1).build(loans: loans, now: pagi);

      expect(plan.slots.first.summary, 'Alat 1, Alat 2, Alat 3, Alat 4 +2 lainnya');
    });
  });

  group('id dan sidik jari', () {
    test('id stabil untuk tanggal dan jam yang sama', () {
      final loans = [detail(due: DateTime(2026, 10, 21))];
      final first = ReminderPlanner(horizonDays: 1).build(loans: loans, now: pagi);
      final second = ReminderPlanner(horizonDays: 1).build(loans: loans, now: pagi);

      expect(
        first.slots.map((slot) => slot.id),
        second.slots.map((slot) => slot.id),
      );
      expect(first.slots.map((slot) => slot.id).toSet(), hasLength(3));
    });

    test('sidik jari berubah hanya saat isi rencana berubah', () {
      final loans = [detail(due: DateTime(2026, 10, 21))];
      final planner = ReminderPlanner(horizonDays: 1);
      final awal = planner.build(loans: loans, now: pagi);
      final sama = planner.build(loans: loans, now: pagi);
      final berubah = planner.build(
        loans: [...loans, detail(id: 2, item: 'Kamera', due: DateTime(2026, 10, 21))],
        now: pagi,
      );

      expect(sama.signature, awal.signature);
      expect(berubah.signature, isNot(awal.signature));
    });
  });
}
