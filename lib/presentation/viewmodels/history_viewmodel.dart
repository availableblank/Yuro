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
      : _repository = repository {
    // 监听 repository 变更（如外部增删）
    _repository.addListener(_onRepositoryChanged);
  }

  // ── Getters ──

  List<HistoryRecord> get records => _records;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;

  /// 当前已加载条数
  int get loadedCount => _records.length;

  /// 匹配搜索的总条数
  int get totalCount => _repository.totalCount(query: _searchQuery);

  // ── 公开方法 ──

  /// 初始加载（重置并加载前 20 条）
  Future<void> loadInitial({String query = ''}) async {
    _searchQuery = query;
    _records = [];
    _hasMore = true;
    await _loadMore();
  }

  /// 加载下一页
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    await _loadMore();
  }

  /// 搜索
  Future<void> search(String query) async {
    if (_searchQuery == query && _records.isNotEmpty) return;
    await loadInitial(query: query);
  }

  /// 清除搜索
  Future<void> clearSearch() async {
    if (_searchQuery.isEmpty) return;
    await loadInitial(query: '');
  }

  /// 删除单条
  Future<void> removeRecord(int workId) async {
    await _repository.removeRecord(workId);
    // 从本地列表同步移除
    _records.removeWhere((r) => r.workId == workId);
    // 如果删除后不足一页且有更多，自动补加载
    if (_records.length < _pageSize && _hasMore) {
      await _loadMore();
    } else {
      notifyListeners();
    }
  }

  /// 清空全部
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
      // 模拟短暂延迟让UI更流畅（可选）
      await Future.delayed(const Duration(milliseconds: 100));

      final newRecords = _repository.getPaged(
        offset: _records.length,
        limit: _pageSize,
        query: _searchQuery,
      );

      if (newRecords.isEmpty) {
        _hasMore = false;
      } else {
        _records.addAll(newRecords);
        // 判断是否还有更多
        _hasMore = _records.length < _repository.totalCount(query: _searchQuery);
      }
    } catch (e) {
      debugPrint('HistoryViewModel: 加载失败 - $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onRepositoryChanged() {
    // 外部修改（如新播放记录）后刷新当前列表
    // 简单方案：重置并重新加载
    loadInitial(query: _searchQuery);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}