import '../core/dates.dart';
import '../core/exceptions.dart';

enum LoanStatus {
  borrowed('dipinjam'),
  returned('selesai');

  const LoanStatus(this.dbValue);

  final String dbValue;

  static LoanStatus fromDb(String value) => LoanStatus.values.firstWhere(
        (status) => status.dbValue == value,
        orElse: () =>
            throw ValidationException('Status peminjaman tidak dikenali: $value'),
      );
}

/// Keadaan satu peminjaman pada hari tertentu. "Terlambat" tidak disimpan,
/// jadi selalu diturunkan dari tanggal.
enum LoanTimeliness { active, overdue, returnedOnTime, returnedLate }

/// Label dan angka keterlambatan yang dipakai bersama oleh kartu riwayat,
/// daftar, dan berkas ekspor.
class LoanStatusView {
  const LoanStatusView({
    required this.state,
    required this.daysLate,
    required this.label,
  });

  final LoanTimeliness state;
  final int daysLate;
  final String label;

  bool get isLate =>
      state == LoanTimeliness.overdue || state == LoanTimeliness.returnedLate;

  factory LoanStatusView.of(Loan loan, DateTime today) {
    if (loan.status == LoanStatus.returned) {
      final returnDate = loan.returnDate;
      if (returnDate != null && isBeforeDay(loan.dueDate, returnDate)) {
        final days = dateOnly(returnDate)
            .difference(dateOnly(loan.dueDate))
            .inDays;
        return LoanStatusView(
          state: LoanTimeliness.returnedLate,
          daysLate: days,
          label: 'Terlambat $days hari',
        );
      }
      return const LoanStatusView(
        state: LoanTimeliness.returnedOnTime,
        daysLate: 0,
        label: 'Tepat Waktu',
      );
    }
    if (loan.isLateOn(today)) {
      final days = loan.daysLateOn(today);
      return LoanStatusView(
        state: LoanTimeliness.overdue,
        daysLate: days,
        label: 'Terlambat $days hari',
      );
    }
    return const LoanStatusView(
      state: LoanTimeliness.active,
      daysLate: 0,
      label: 'Dipinjam',
    );
  }
}

class Loan {
  const Loan({
    this.id,
    required this.itemId,
    required this.borrowerName,
    this.contact,
    required this.quantity,
    required this.loanDate,
    required this.dueDate,
    this.returnDate,
    this.status = LoanStatus.borrowed,
    this.note,
  });

  factory Loan.fromMap(Map<String, Object?> map) => Loan(
        id: map['id'] as int?,
        itemId: map['item_id'] as int,
        borrowerName: map['borrower_name'] as String,
        contact: map['contact'] as String?,
        quantity: map['quantity'] as int,
        loanDate: parseDate(map['loan_date'] as String),
        dueDate: parseDate(map['due_date'] as String),
        returnDate: map['return_date'] == null
            ? null
            : parseDate(map['return_date'] as String),
        status: LoanStatus.fromDb(map['status'] as String),
        note: map['note'] as String?,
      );

  final int? id;
  final int itemId;
  final String borrowerName;
  final String? contact;
  final int quantity;
  final DateTime loanDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final LoanStatus status;
  final String? note;

  /// Overdue is presentation-only: the stored status stays `dipinjam`.
  bool isLateOn(DateTime today) =>
      status == LoanStatus.borrowed && isBeforeDay(dueDate, today);

  /// Berapa hari sudah lewat tenggat; 0 kalau belum lewat. Ditaruh di model
  /// supaya label "Terlambat N hari" sama di beranda, riwayat, dan detail.
  int daysLateOn(DateTime today) => isLateOn(today)
      ? dateOnly(today).difference(dateOnly(dueDate)).inDays
      : 0;

  /// Satu klasifikasi status untuk UI dan ekspor, supaya keduanya tidak
  /// berbeda cerita tentang peminjaman yang sama.
  LoanStatusView statusOn(DateTime today) => LoanStatusView.of(this, today);

  Map<String, Object?> toMap() => {
        'id': id,
        'item_id': itemId,
        'borrower_name': borrowerName,
        'contact': contact,
        'quantity': quantity,
        'loan_date': formatDate(loanDate),
        'due_date': formatDate(dueDate),
        'return_date': returnDate == null ? null : formatDate(returnDate!),
        'status': status.dbValue,
        'note': note,
      };

  Loan copyWith({
    int? id,
    int? itemId,
    String? borrowerName,
    String? contact,
    int? quantity,
    DateTime? loanDate,
    DateTime? dueDate,
    DateTime? returnDate,
    LoanStatus? status,
    String? note,
  }) =>
      Loan(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        borrowerName: borrowerName ?? this.borrowerName,
        contact: contact ?? this.contact,
        quantity: quantity ?? this.quantity,
        loanDate: loanDate ?? this.loanDate,
        dueDate: dueDate ?? this.dueDate,
        returnDate: returnDate ?? this.returnDate,
        status: status ?? this.status,
        note: note ?? this.note,
      );
}
