import '../core/dates.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../models/reminder.dart';

/// Penyusun jadwal pengingat. Fungsi murni: tidak menyentuh database, plugin
/// notifikasi, maupun jam sistem — semuanya masuk lewat parameter, sehingga
/// seluruh aturan bisa diuji tanpa perangkat Android.
///
/// Waktu yang dipakai adalah waktu dinding WIB. Pemanggil bertanggung jawab
/// mengubah "sekarang" ke WIB sebelum memanggil [build], dan mengubah hasil
/// [ReminderSlot.when] menjadi TZDateTime saat menjadwalkan.
class ReminderPlanner {
  const ReminderPlanner({
    this.horizonDays = 90,
    this.hours = const [9, 13, 15],
  });

  /// Berapa hari ke depan jadwal dibuat. Sinkronisasi berikutnya memperpanjang.
  final int horizonDays;

  /// Jam pengiriman dalam WIB, urut naik.
  final List<int> hours;

  /// Jumlah barang yang ditulis penuh di isi notifikasi.
  static const maxListed = 5;

  /// Jumlah nama barang di ringkasan satu baris.
  static const maxSummaryNames = 4;

  ReminderPlan build({required List<LoanDetail> loans, required DateTime now}) {
    final active = loans
        .where((detail) => detail.loan.status == LoanStatus.borrowed)
        .toList()
      ..sort((a, b) => (a.loan.id ?? 0).compareTo(b.loan.id ?? 0));

    final today = dateOnly(now);
    final slots = <ReminderSlot>[];

    for (var offset = 0; offset < horizonDays; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      for (var index = 0; index < hours.length; index++) {
        final when = DateTime(day.year, day.month, day.day, hours[index]);
        // Slot hari ini yang jamnya sudah lewat tidak perlu dijadwalkan.
        if (!when.isAfter(now)) {
          continue;
        }

        final dueToday = <ReminderEntry>[];
        final overdue = <ReminderEntry>[];
        for (final detail in active) {
          final daysLate = daysBetween(detail.loan.dueDate, day);
          // Barang yang tenggatnya masih di depan belum perlu diingatkan.
          if (daysLate < 0) {
            continue;
          }
          final entry = ReminderEntry(
            loanId: detail.loan.id ?? 0,
            itemName: detail.item.name,
            borrowerName: detail.loan.borrowerName,
            quantity: detail.loan.quantity,
            daysLate: daysLate,
          );
          if (daysLate == 0) {
            dueToday.add(entry);
          } else {
            overdue.add(entry);
          }
        }

        if (dueToday.isEmpty && overdue.isEmpty) {
          continue;
        }

        dueToday.sort((a, b) => a.itemName.compareTo(b.itemName));
        overdue.sort((a, b) {
          final byDays = b.daysLate.compareTo(a.daysLate);
          return byDays != 0 ? byDays : a.itemName.compareTo(b.itemName);
        });

        final ordered = [...dueToday, ...overdue];
        slots.add(
          ReminderSlot(
            id: reminderNotificationId(day, index),
            when: when,
            title: _title(dueToday, overdue),
            summary: _summary(ordered),
            detail: _detail(ordered),
            entries: ordered,
          ),
        );
      }
    }

    return ReminderPlan(slots: slots, signature: _signature(active, today));
  }

  String _title(List<ReminderEntry> dueToday, List<ReminderEntry> overdue) {
    if (dueToday.isNotEmpty && overdue.isNotEmpty) {
      return '${dueToday.length} harus kembali hari ini · '
          '${overdue.length} terlambat';
    }
    if (dueToday.isNotEmpty) {
      return '${dueToday.length} barang harus dikembalikan hari ini';
    }
    if (overdue.length == 1) {
      return 'Terlambat ${overdue.single.daysLate} hari';
    }
    final maxDays = overdue.map((entry) => entry.daysLate).reduce((a, b) => a > b ? a : b);
    final uniform = overdue.every((entry) => entry.daysLate == maxDays);
    return uniform
        ? 'Terlambat $maxDays hari · ${overdue.length} barang'
        : '${overdue.length} barang belum dikembalikan';
  }

  String _summary(List<ReminderEntry> ordered) {
    final names = ordered
        .take(maxSummaryNames)
        .map((entry) => entry.itemName)
        .join(', ');
    final rest = ordered.length - maxSummaryNames;
    return rest > 0 ? '$names +$rest lainnya' : names;
  }

  String _detail(List<ReminderEntry> ordered) {
    final buffer = StringBuffer();
    for (final entry in ordered.take(maxListed)) {
      final late = entry.isDueToday ? '' : ' · terlambat ${entry.daysLate} hari';
      buffer.writeln(
        '• ${entry.itemName} — ${entry.borrowerName} '
        '(${entry.quantity} unit)$late',
      );
    }
    final rest = ordered.length - maxListed;
    if (rest > 0) {
      buffer.writeln('… dan $rest barang lainnya');
    }
    buffer.writeln();
    buffer.write('Ketuk untuk membuka daftar');
    return buffer.toString();
  }

  /// Sidik jari isi rencana. Nama barang dan peminjam ikut dihitung karena
  /// keduanya tampil di teks notifikasi.
  String _signature(List<LoanDetail> active, DateTime today) {
    final loans = active
        .map(
          (detail) => '${detail.loan.id}:${dayNumber(detail.loan.dueDate)}:'
              '${detail.loan.quantity}:${detail.item.name}:'
              '${detail.loan.borrowerName}',
        )
        .join('|');
    return '${dayNumber(today)}#$horizonDays#${hours.join(',')}#$loans';
  }
}
