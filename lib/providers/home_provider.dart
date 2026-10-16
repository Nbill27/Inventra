import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import '../core/exceptions.dart';
import '../models/item_stats.dart';
import '../models/loan_detail.dart';
import '../models/loan_stats.dart';
import '../repositories/item_repository.dart';
import '../repositories/loan_repository.dart';

/// Data ringkasan untuk layar Beranda.
///
/// Semuanya dihitung database lewat query agregat, bukan dengan memuat seluruh
/// baris lalu menghitungnya di memori, supaya beranda tetap murah berapa pun
/// besar datanya.
class HomeProvider extends ChangeNotifier {
  HomeProvider({ItemRepository? itemRepository, LoanRepository? loanRepository})
      : _items = itemRepository ?? ItemRepository(),
        _loans = loanRepository ?? LoanRepository();

  /// Berapa peminjaman terbaru yang ditampilkan beranda.
  static const recentLimit = 4;

  final ItemRepository _items;
  final LoanRepository _loans;

  ItemStats _itemStats = const ItemStats();
  LoanStats _loanStats = const LoanStats();
  List<LoanDetail> _recent = const [];
  bool _isLoading = false;
  String? _errorMessage;
  int _requestId = 0;

  ItemStats get itemStats => _itemStats;
  LoanStats get loanStats => _loanStats;
  List<LoanDetail> get recent => _recent;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Ketiga permintaan dibuat lebih dulu supaya berjalan bersamaan, bukan
      // berurutan.
      final itemStatsFuture = _items.stats();
      final loanStatsFuture = _loans.stats(today: dateOnly(DateTime.now()));
      final recentFuture = _loans.getAllDetailed(limit: recentLimit);

      final itemStats = await itemStatsFuture;
      final loanStats = await loanStatsFuture;
      final recent = await recentFuture;

      if (requestId != _requestId) {
        return;
      }
      _itemStats = itemStats;
      _loanStats = loanStats;
      _recent = recent;
    } on AppException catch (error) {
      if (requestId == _requestId) {
        _errorMessage = error.message;
      }
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat ringkasan beranda: $error\n$stackTrace');
      if (requestId == _requestId) {
        _errorMessage = 'Gagal memuat ringkasan beranda.';
      }
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
