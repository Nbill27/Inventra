import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../models/loan.dart';
import '../models/loan_detail.dart';
import '../repositories/loan_repository.dart';

class LoanProvider extends ChangeNotifier {
  LoanProvider({LoanRepository? repository})
      : _repository = repository ?? LoanRepository();

  final LoanRepository _repository;

  List<LoanDetail> _loans = const [];
  bool _isLoading = false;
  String? _errorMessage;

  /// Empty means "all statuses", so the list screen can offer a multi-select
  /// filter without a separate "everything" flag.
  Set<LoanStatus> _statusFilters = const {};
  int _requestId = 0;

  List<LoanDetail> get loans => _loans;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Set<LoanStatus> get statusFilters => _statusFilters;

  Future<void> load() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loans = await _repository.getAllDetailed(statuses: _statusFilters);
      if (requestId != _requestId) {
        return;
      }
      _loans = loans;
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

  /// An empty set shows every status.
  Future<void> filterBy(Set<LoanStatus> statuses) async {
    _statusFilters = statuses;
    await load();
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
