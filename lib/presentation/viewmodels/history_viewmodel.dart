import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/data/models/history/history_record.dart';
import 'package:asmrapp/data/models/works/work.dart';
import 'package:asmrapp/data/repositories/history_repository.dart';
import 'package:asmrapp/utils/logger.dart';

/// 历史记录页面状态管理
///
/// 负责：
/// - 分页加载（每页 20 条，触底加载更多）
/// - 本地搜索过滤
/// - 单条删除 / 全部清空
class HistoryViewModel extends ChangeNotifier {
  static const int _pageSize = 20;

  final HistoryRepository _repository;

  // 所有已加载到内存中的记录（用于搜索）
  List<HistoryRecord> _allLoadedRecords = [];

  // 当前显示的记录（分页或搜索过滤后）
  List<HistoryRecord> _displayedRecords = [];

  // 搜索结果缓存
  List<HistoryRecord>? _searchResults;

  // 当前搜索关键词
  String _searchQuery = '';

  // 分页状态
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;

  HistoryViewModel({HistoryRepository? repository})
      : _repository = repository ?? GetIt.I<HistoryRepository>();

  // ─── Getters ───

  List<HistoryRecord> get displayedRecords => _displayedRecords;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String get searchQuery => _searchQuery;
  bool get isSearching => _searchQuery.isNotEmpty;
  int get totalCount => _repository.totalCount;

  // ─── 加载 ───

  /// 初始加载（首页 20 条）
  Future<void> loadInitial() async {
    _isLoading = true;
    _currentOffset = 0;
    _searchQuery = '';
    _searchResults = null;
    notifyListeners();

    try {
      _allLoadedRecords = _repository.getRecords(offset: 0, limit: _pageSize);
      _displayedRecords = List.from(_allLoadedRecords);
      _currentOffset = _allLoadedRecords.length;
      _hasMore = _allLoadedRecords.length >= _pageSize &&
          _currentOffset < _repository.totalCount;
    } catch (e) {
      AppLogger.error('加载历史记录失败', e);
      _displayedRecords = [];
      _hasMore = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载更多（触底时调用）
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) return;
    // 搜索模式下不支持加载更多
    if (isSearching) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newRecords =
          _repository.getRecords(offset: _currentOffset, limit: _pageSize);

      if (newRecords.isEmpty) {
        _hasMore = false;
      } else {
        _allLoadedRecords.addAll(newRecords);
        _displayedRecords = List.from(_allLoadedRecords);
        _currentOffset = _allLoadedRecords.length;
        _hasMore = _currentOffset < _repository.totalCount;
      }
    } catch (e) {
      AppLogger.error('加载更多历史记录失败', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新（重新加载首页）
  Future<void> refresh() async {
    await loadInitial();
  }

  // ─── 搜索 ───

  /// 执行搜索
  void search(String query) {
    _searchQuery = query;

    if (query.trim().isEmpty) {
      // 清空搜索，恢复分页视图
      _searchResults = null;
      _displayedRecords = List.from(_allLoadedRecords);
    } else {
      _searchResults = _repository.searchRecords(query);
      _displayedRecords = List.from(_searchResults!);
    }
    notifyListeners();
  }

  /// 清空搜索
  void clearSearch() {
    _searchQuery = '';
    _searchResults = null;
    _displayedRecords = List.from(_allLoadedRecords);
    notifyListeners();
  }

  // ─── 删除 ───

  /// 删除单条记录
  Future<void> deleteRecord(int workId) async {
    try {
      await _repository.removeRecord(workId);

      // 从本地列表中移除
      _allLoadedRecords.removeWhere((r) => r.workId == workId);
      _searchResults?.removeWhere((r) => r.workId == workId);

      // 刷新显示列表
      if (isSearching) {
        _displayedRecords = List.from(_searchResults ?? []);
      } else {
        _displayedRecords = List.from(_allLoadedRecords);
      }

      // 如果删除后列表变短，尝试补充加载
      if (!isSearching &&
          _allLoadedRecords.length < _pageSize &&
          _currentOffset < _repository.totalCount) {
        final supplement = _repository.getRecords(
          offset: _currentOffset,
          limit: _pageSize - _allLoadedRecords.length,
        );
        _allLoadedRecords.addAll(supplement);
        _currentOffset = _allLoadedRecords.length;
        _displayedRecords = List.from(_allLoadedRecords);
        _hasMore = _currentOffset < _repository.totalCount;
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('删除历史记录失败', e);
    }
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    try {
      await _repository.clearAll();
      _allLoadedRecords = [];
      _displayedRecords = [];
      _searchResults = null;
      _searchQuery = '';
      _currentOffset = 0;
      _hasMore = false;
      notifyListeners();
    } catch (e) {
      AppLogger.error('清空历史记录失败', e);
    }
  }

  // ─── 辅助 ───

  /// 从 HistoryRecord 重建 Work 对象（用于导航到详情页）
  Work? reconstructWork(HistoryRecord record) {
    return HistoryRepository.reconstructWork(record);
  }
}