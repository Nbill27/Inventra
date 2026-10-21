import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../core/exceptions.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../models/loan_stats.dart';
import '../repositories/loan_repository.dart';
import '../services/reminder_scheduler.dart';

class LoanProvider extends ChangeNotifier {
  LoanProvider({
    LoanRepository? repository,
    DateTime Function()? clock,
    this.reminderSync,
  })  : _repository = repository ?? LoanRepository(),
        _clock = clock ?? DateTime.now;

  final LoanRepository _repository;

  /// Penyusun ulang jadwal pengingat. Null di test yang tidak menguji notifikasi.
  final ReminderSync? reminderSync;

  /// Sumber "hari ini". Bisa diganti di test supaya pergantian hari tidak
  /// perlu menunggu tengah malam sungguhan.
  final DateTime Function() _clock;

  List<LoanDetail> _loans = const [];
  LoanStats _stats = const LoanStats();
  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;

  /// Hari data terakhir dimuat. Dipakai [isStale] untuk tahu data sudah basi.
  DateTime? _loadedOn;

  List<LoanDetail> get loans => _loans;
  LoanStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Hari ini menurut jam aplikasi, dipakai filter "Terlambat" dan ringkasan.
  DateTime get today => dateOnly(_clock());

  /// True saat data terakhir dimuat pada hari yang berbeda.
  ///
  /// Kategori "Terlambat" dan ringkasan dihitung saat memuat, jadi aplikasi
  /// yang dibiarkan terbuka sampai lewat tengah malam akan menampilkan angka
  /// kemarin. Layar memanggil [load] lagi ketika ini true.
  bool get isStale {
    final loadedOn = _loadedOn;
    return loadedOn == null || loadedOn != today;
  }

  Future<void> load() async {
    final requestId = ++_requestId;
    // Dipatok sekali supaya daftar dan ringkasan memakai hari yang sama,
    // walau pemuatan menyeberangi pergantian hari.
    final loadDay = today;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Daftar dan angka ringkasan diambil bersamaan supaya Beranda tidak
      // menunggu dua kali.
      final results = await Future.wait<Object>([
        _repository.getAllDetailed(),
        _repository.stats(today: loadDay),
      ]);
      if (requestId != _requestId) {
        return;
      }
      _loans = results[0] as List<LoanDetail>;
      _stats = results[1] as LoanStats;
      _loadedOn = loadDay;
    } on AppException catch (error) {
      if (requestId == _requestId) {
        _errorMessage = error.message;
      }
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat peminjaman: $error\n$stackTrace');
      if (requestId == _requestId) {
        _errorMessage = 'Gagal memuat daftar peminjaman.';
      }
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Returns the error message to show, or null when the write succeeded.
  Future<String?> create(Loan loan) => _mutate(() => _repository.create(loan));

  Future<String?> update(Loan loan) => _mutate(() => _repository.update(loan));

  Future<String?> markReturned({required int loanId, required DateTime returnDate}) =>
      _mutate(() => _repository.markReturned(loanId: loanId, returnDate: returnDate));

  Future<String?> delete(int id) => _mutate(() => _repository.delete(id));

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on AppException catch (error) {
      return error.message;
    } catch (error, stackTrace) {
      debugPrint('Gagal menyimpan peminjaman: $error\n$stackTrace');
      return 'Gagal menyimpan data peminjaman.';
    }
    await load();
    // Dijalankan tanpa ditunggu: pengingat tidak boleh memperlambat tombol
    // "Dikembalikan". Kegagalannya sudah ditangani di dalam scheduler.
    unawaited(reminderSync?.sync() ?? Future<void>.value());
    return null;
  }
}
