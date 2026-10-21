import '../core/dates.dart';

/// Satu barang yang ikut disebut di dalam satu notifikasi pengingat.
///
/// [daysLate] bernilai 0 untuk barang yang jatuh tempo tepat pada hari slot
/// tersebut; angka itu dihitung dari tanggal slot, bukan dari hari ini,
/// sehingga teks notifikasi tetap benar walau aplikasi lama tidak dibuka.
class ReminderEntry {
  const ReminderEntry({
    required this.loanId,
    required this.itemName,
    required this.borrowerName,
    required this.quantity,
    required this.daysLate,
  });

  final int loanId;
  final String itemName;
  final String borrowerName;
  final int quantity;
  final int daysLate;

  bool get isDueToday => daysLate == 0;
}

/// Satu notifikasi terjadwal: judul, isi ringkas (tampilan terkuncup), dan isi
/// panjang (tampilan setelah ditarik).
class ReminderSlot {
  const ReminderSlot({
    required this.id,
    required this.when,
    required this.title,
    required this.summary,
    required this.detail,
    required this.entries,
  });

  /// ID notifikasi Android. Deterministik dari tanggal + jam, sehingga
  /// penjadwalan ulang tidak pernah menghasilkan notifikasi kembar.
  final int id;

  /// Waktu kirim dalam waktu dinding WIB (bukan UTC, bukan zona perangkat).
  final DateTime when;

  final String title;
  final String summary;
  final String detail;
  final List<ReminderEntry> entries;
}

/// Seluruh jadwal yang seharusnya terpasang di sistem.
class ReminderPlan {
  const ReminderPlan({required this.slots, required this.signature});

  static const empty = ReminderPlan(slots: [], signature: '');

  final List<ReminderSlot> slots;

  /// Sidik jari isi rencana. Kalau nilainya sama dengan yang tersimpan,
  /// penjadwalan ulang bisa dilewati sepenuhnya.
  final String signature;

  bool get isEmpty => slots.isEmpty;
}

/// ID notifikasi dipisahkan ke rentang tinggi (1.000.000.000+) supaya tidak
/// bertabrakan dengan notifikasi lain yang mungkin ditambahkan nanti.
int reminderNotificationId(DateTime day, int slotIndex) =>
    1000000000 + (day.year * 10000 + day.month * 100 + day.day) * 10 + slotIndex;

/// Nomor urut hari (YYYYMMDD) untuk keperluan perbandingan tanggal saja.
int dayNumber(DateTime day) => day.year * 10000 + day.month * 100 + day.day;

/// Selisih hari kalender antara dua tanggal, mengabaikan jam.
int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;
