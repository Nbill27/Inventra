import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../core/exceptions.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../models/loan_stats.dart';
import '../repositories/loan_repository.dart';

class LoanProvider extends ChangeNotifier {
  LoanProvider({LoanRepository? repository})
      : _repository = repository ?? LoanRepository();

  final LoanRepository _repository;

  List<LoanDetail> _loans = const [];
  LoanStats _stats = const LoanStats();
  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;

  List<LoanDetail> get loans => _loans;
  LoanStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Daftar dan angka ringkasan diambil bersamaan supaya Beranda tidak
      // menunggu dua kali.
      final results = await Future.wait<Object>([
        _repository.getAllDetailed(),
        _repository.stats(today: dateOnly(DateTime.now())),
      ]);
      if (requestId != _requestId) {
        return;
      }
      _loans = results[0] as List<LoanDetail>;
      _stats = results[1] as LoanStats;
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
    return null;
  }
}
