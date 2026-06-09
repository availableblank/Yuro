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

  /// 从 SharedPreferences 读取全部记录（已按时间倒序）
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
      // 保证倒序（最新在前）
      _cachedAll!.sort((a, b) => b.lastPlayedTime.compareTo(a.lastPlayedTime));
      return _cachedAll!;
    } catch (e) {
      debugPrint('HistoryRepository: 解析历史记录失败 - $e');
      _cachedAll = [];
      return _cachedAll!;
    }
  }

  /// 持久化全部记录
  Future<void> _writeAll(List<HistoryRecord> records) async {
    // 按上限截断
    final max = _settings.maxCount;
    if (records.length > max) {
      records = records.sublist(0, max);
    }

    final list = records.map((r) => r.toJson()).toList();
    await _prefs.setString(_keyHistory, jsonEncode(list));
    _cachedAll = records;
  }

  /// 按 workId 去重：已存在则更新时间/进度/文件名，否则插入到最前
  Future<void> addOrUpdate(HistoryRecord record) async {
    final all = _readAll();
    final index = all.indexWhere((r) => r.workId == record.workId);

    if (index != -1) {
      // 已存在：更新信息并移到最前
      final updated = all[index].updatePlayInfo(
        time: record.lastPlayedTime,
        progressSeconds: record.lastProgressSeconds,
        fileName: record.lastPlayedFileName,
      );
      all.removeAt(index);
      all.insert(0, updated);
    } else {
      // 新纪录：插入到最前
      all.insert(0, record);
    }

    await _writeAll(all);
    notifyListeners();
  }

  /// 获取分页记录
  /// [offset] 起始索引，[limit] 每页条数，[query] 搜索关键字（可选）
  List<HistoryRecord> getPaged({
    required int offset,
    required int limit,
    String query = '',
  }) {
    List<HistoryRecord> source = _readAll();

    // 搜索过滤
    if (query.isNotEmpty) {
      source = source.where((r) => r.matchesQuery(query)).toList();
    }

    if (offset >= source.length) return [];
    final end = (offset + limit).clamp(0, source.length);
    return source.sublist(offset, end);
  }

  /// 获取总记录数（用于分页判断）
  int totalCount({String query = ''}) {
    if (query.isEmpty) return _readAll().length;
    return _readAll().where((r) => r.matchesQuery(query)).length;
  }

  /// 删除单条记录
  Future<void> removeRecord(int workId) async {
    final all = _readAll();
    all.removeWhere((r) => r.workId == workId);
    await _writeAll(all);
    notifyListeners();
  }

  /// 清空所有记录
  Future<void> clearAll() async {
    _cachedAll = [];
    await _prefs.setString(_keyHistory, '[]');
    notifyListeners();
  }

  /// 供外部监听上限变更后裁剪
  void onMaxCountChanged() {
    final all = _readAll();
    if (all.length > _settings.maxCount) {
      _writeAll(all); // _writeAll 内部会截断
    }
  }
}