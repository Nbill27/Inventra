import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../models/item.dart';
import '../models/item_filter.dart';
import '../models/item_import.dart';
import '../repositories/item_repository.dart';

class ItemProvider extends ChangeNotifier {
  ItemProvider({ItemRepository? repository})
      : _repository = repository ?? ItemRepository();

  final ItemRepository _repository;

  List<Item> _items = const [];
  bool _isLoading = false;
  String? _errorMessage;
  String _query = '';

  /// `null` berarti semua kategori; hanya satu kategori bisa aktif sekaligus.
  ItemFilter? _filter;
  int _requestId = 0;

  List<Item> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get query => _query;
  ItemFilter? get filter => _filter;

  Future<void> load() async {
    final requestId = ++_requestId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await _repository.getAll(query: _query, filter: _filter);
      if (requestId != _requestId) {
        return;
      }
      _items = items;
    } on AppException catch (error) {
      if (requestId == _requestId) {
        _errorMessage = error.message;
      }
    } catch (error, stackTrace) {
      debugPrint('Gagal memuat barang: $error\n$stackTrace');
      if (requestId == _requestId) {
        _errorMessage = 'Gagal memuat daftar barang.';
      }
    } finally {
      if (requestId == _requestId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> search(String value) async {
    _query = value;
    await load();
  }

  /// `null` menampilkan semua kategori.
  Future<void> filterBy(ItemFilter? filter) async {
    _filter = filter;
    await load();
  }

  /// The full item list, ignoring whatever is typed in the search box.
  ///
  /// Screens that pick an item (the loan form) must not inherit the list
  /// screen's filter, otherwise a leftover search could hide the item that is
  /// about to be borrowed.
  Future<List<Item>> allItems() => _repository.getAll();

  /// Returns the error message to show, or null when the write succeeded.
  Future<String?> create(Item item) => _mutate(() => _repository.create(item));

  Future<String?> update(Item item) => _mutate(() => _repository.update(item));

  Future<String?> delete(int id) => _mutate(() => _repository.delete(id));

  /// Rows rejected by validation come back inside the report instead of failing
  /// the whole file, so only a storage-level failure is thrown here.
  Future<ImportReport> importItems(List<ItemDraft> drafts) async {
    try {
      final report = await _repository.importItems(drafts);
      await load();
      return report;
    } on AppException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Gagal mengimpor barang: $error\n$stackTrace');
      throw const StorageException('Gagal mengimpor data barang.');
    }
  }

  Future<String?> _mutate(Future<void> Function() action) async {
    try {
      await action();
    } on AppException catch (error) {
      return error.message;
    } catch (error, stackTrace) {
      debugPrint('Gagal menyimpan barang: $error\n$stackTrace');
      return 'Gagal menyimpan data barang.';
    }
    await load();
    return null;
  }
}
