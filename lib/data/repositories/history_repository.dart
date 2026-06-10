import 'dart:convert';
import 'package:asmrapp/data/models/history/history_record.dart';
import 'package:asmrapp/core/cache/history_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryRepository extends ChangeNotifier {
  static const _keyHistory = 'playback_history';

  final SharedPreferences _prefs;
  final HistorySettings _settings;

  List<HistoryRecord>? _cachedAll;

  HistoryRepository({
    required SharedPreferences prefs,
    required HistorySettings settings,
  })  : _prefs = prefs,
        _settings = settings;

  // ── 内部读写 ──

  List<HistoryRecord> _readAll() {
    if (_cachedAll != null) return _cachedAll!;

    final raw = _prefs.getString(_keyHistory);
    if (raw == null || raw.isEmpty) {
      _cachedAll = [];
      return _cachedAll!;
    }

    try {
      final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
      _cachedAll = list
          .map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
      _cachedAll!.sort((a, b) => b.lastPlayedTime.compareTo(a.lastPlayedTime));
      return _cachedAll!;
    } catch (e) {
      debugPrint('HistoryRepository: 解析失败 - $e');
      _cachedAll = [];
      return _cachedAll!;
    }
  }

  Future<void> _writeAll(List<HistoryRecord> records) async {
    final max = _settings.maxCount;
    if (records.length > max) {
      records = records.sublist(0, max);
    }

    final list = records.map((r) => r.toJson()).toList();
    await _prefs.setString(_keyHistory, jsonEncode(list));
    _cachedAll = records;
  }

  /// 清除内存缓存（供 HistorySettings 变更时强制重读）
  void invalidateCache() {
    _cachedAll = null;
  }

  // ── 公开方法 ──

  /// 添加或更新一条记录。
  /// 静默写入，不触发 notifyListeners（避免每 2 秒打断 UI 分页状态）
  Future<void> addOrUpdate(HistoryRecord record) async {
    final all = _readAll();
    final index = all.indexWhere((r) => r.workId == record.workId);

    if (index != -1) {
      final updated = all[index].updatePlayInfo(
        time: record.lastPlayedTime,
        progressSeconds: record.lastProgressSeconds,
        fileName: record.lastPlayedFileName,
      );
      all.removeAt(index);
      all.insert(0, updated);
    } else {
      all.insert(0, record);
    }

    await _writeAll(all);
    // 故意不调用 notifyListeners()
  }

  List<HistoryRecord> getPaged({
    required int offset,
    required int limit,
    String query = '',
  }) {
    // 每次都重新读取以保证数据最新（进入历史页时）
    invalidateCache();
    List<HistoryRecord> source = _readAll();

    if (query.isNotEmpty) {
      source = source.where((r) => r.matchesQuery(query)).toList();
    }

    if (offset >= source.length) return [];
    final end = (offset + limit).clamp(0, source.length);
    return source.sublist(offset, end);
  }

  int totalCount({String query = ''}) {
    invalidateCache();
    final all = _readAll();
    if (query.isEmpty) return all.length;
    return all.where((r) => r.matchesQuery(query)).length;
  }

  /// 删除单条 —— 触发 UI 更新
  Future<void> removeRecord(int workId) async {
    final all = _readAll();
    all.removeWhere((r) => r.workId == workId);
    await _writeAll(all);
    notifyListeners();
  }

  /// 清空全部 —— 触发 UI 更新
  Future<void> clearAll() async {
    _cachedAll = [];
    await _prefs.setString(_keyHistory, '[]');
    notifyListeners();
  }
}