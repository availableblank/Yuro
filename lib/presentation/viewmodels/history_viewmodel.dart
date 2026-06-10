import 'package:flutter/foundation.dart';
import 'package:asmrapp/data/models/history/history_record.dart';
import 'package:asmrapp/data/repositories/history_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  final HistoryRepository _repository;

  static const int _pageSize = 20;

  List<HistoryRecord> _records = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String _searchQuery = '';

  HistoryViewModel({required HistoryRepository repository})
      : _repository = repository;

  // ── Getters ──

  List<HistoryRecord> get records => _records;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;
  int get loadedCount => _records.length;
  int get totalCount => _repository.totalCount(query: _searchQuery);

  // ── 公开方法 ──

  Future<void> loadInitial({String query = ''}) async {
    _searchQuery = query;
    _records = [];
    _hasMore = true;
    await _loadMore();
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    await _loadMore();
  }

  Future<void> search(String query) async {
    if (_searchQuery == query && _records.isNotEmpty) return;
    await loadInitial(query: query);
  }

  Future<void> clearSearch() async {
    if (_searchQuery.isEmpty) return;
    await loadInitial(query: '');
  }

  Future<void> removeRecord(int workId) async {
    await _repository.removeRecord(workId);
    _records.removeWhere((r) => r.workId == workId);
    if (_records.length < _pageSize && _hasMore) {
      await _loadMore();
    } else {
      notifyListeners();
    }
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
    _records = [];
    _hasMore = false;
    notifyListeners();
  }

  // ── 内部 ──

  Future<void> _loadMore() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 80));

      final newRecords = _repository.getPaged(
        offset: _records.length,
        limit: _pageSize,
        query: _searchQuery,
      );

      if (newRecords.isEmpty) {
        _hasMore = false;
      } else {
        _records.addAll(newRecords);
        _hasMore = _records.length < _repository.totalCount(query: _searchQuery);
      }
    } catch (e) {
      debugPrint('HistoryViewModel: 加载失败 - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}