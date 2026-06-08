import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asmrapp/data/models/works/work.dart';
import 'package:asmrapp/data/models/history/history_record.dart';
import 'package:asmrapp/utils/logger.dart';

/// 历史记录持久化仓库
///
/// 使用 SharedPreferences 存储，支持：
/// - 添加/更新记录（同一 workId 会合并为一条，更新时间和进度）
/// - 删除单条 / 清空全部
/// - 分页加载
/// - 自动按上限裁剪
class HistoryRepository {
  static const String _recordsKey = 'history_records';
  static const String _maxCountKey = 'history_max_count';
  static const int _defaultMaxCount = 500;

  final SharedPreferences _prefs;

  HistoryRepository(this._prefs);

  // ─── 上限管理 ───

  /// 获取历史记录上限（默认 500）
  int get maxCount => _prefs.getInt(_maxCountKey) ?? _defaultMaxCount;

  /// 设置历史记录上限
  Future<void> setMaxCount(int count) async {
    await _prefs.setInt(_maxCountKey, count);
    await _trimIfNeeded();
  }

  // ─── 记录操作 ───

  /// 记录或更新作品浏览/播放历史
  ///
  /// 同一 [workId] 会合并为一条记录，更新 [lastPlayedTime] 和可选音频信息。
  /// 自动按上限裁剪最早记录。
  Future<void> recordView(
    Work work, {
    String? audioName,
    int? audioIndex,
    int progressSeconds = 0,
  }) async {
    try {
      final records = _loadAll();
      final workJson = jsonEncode(work.toJson());

      // 查找是否已有该作品的记录
      final existingIndex = records.indexWhere((r) => r.workId == work.id);

      final newRecord = HistoryRecord(
        workId: work.id ?? 0,
        workJson: workJson,
        lastPlayedAudioName: audioName,
        lastPlayedAudioIndex: audioIndex,
        lastPlayedProgressInSeconds: progressSeconds,
        lastPlayedTime: DateTime.now(),
      );

      if (existingIndex != -1) {
        // 合并：保留可能有用的旧音频信息（如果新调用未提供）
        final old = records[existingIndex];
        records[existingIndex] = newRecord.copyWith(
          lastPlayedAudioName: audioName ?? old.lastPlayedAudioName,
          lastPlayedAudioIndex: audioIndex ?? old.lastPlayedAudioIndex,
          lastPlayedProgressInSeconds:
              progressSeconds > 0 ? progressSeconds : old.lastPlayedProgressInSeconds,
        );
      } else {
        records.insert(0, newRecord); // 最新记录在最前
      }

      await _saveAll(records);
      await _trimIfNeeded();
      AppLogger.info('历史记录已更新: workId=${work.id}');
    } catch (e) {
      AppLogger.error('记录历史失败', e);
    }
  }

  /// 更新指定作品的播放进度
  Future<void> updateProgress(int workId, int progressSeconds) async {
    try {
      final records = _loadAll();
      final index = records.indexWhere((r) => r.workId == workId);
      if (index != -1) {
        records[index] = records[index].copyWith(
          lastPlayedProgressInSeconds: progressSeconds,
          lastPlayedTime: DateTime.now(),
        );
        // 移到最前面
        final record = records.removeAt(index);
        records.insert(0, record);
        await _saveAll(records);
      }
    } catch (e) {
      AppLogger.error('更新播放进度失败', e);
    }
  }

  /// 删除单条记录
  Future<void> removeRecord(int workId) async {
    try {
      final records = _loadAll();
      records.removeWhere((r) => r.workId == workId);
      await _saveAll(records);
      AppLogger.info('历史记录已删除: workId=$workId');
    } catch (e) {
      AppLogger.error('删除历史记录失败', e);
    }
  }

  /// 清空所有历史记录
  Future<void> clearAll() async {
    try {
      await _prefs.setString(_recordsKey, '[]');
      AppLogger.info('所有历史记录已清空');
    } catch (e) {
      AppLogger.error('清空历史记录失败', e);
    }
  }

  // ─── 查询操作 ───

  /// 分页加载历史记录（按时间倒序）
  ///
  /// [offset] 起始位置，[limit] 每页条数
  List<HistoryRecord> getRecords({int offset = 0, int limit = 20}) {
    final all = _loadAll();
    final end = (offset + limit).clamp(0, all.length);
    if (offset >= all.length) return [];
    return all.sublist(offset, end);
  }

  /// 获取总记录数
  int get totalCount => _loadAll().length;

  /// 搜索历史记录（匹配作品标题/音频名）
  List<HistoryRecord> searchRecords(String query) {
    if (query.trim().isEmpty) return _loadAll();
    final lowerQuery = query.toLowerCase();
    return _loadAll().where((r) {
      // 尝试从 workJson 中提取标题进行匹配
      try {
        final workMap = jsonDecode(r.workJson) as Map<String, dynamic>;
        final title = (workMap['title'] ?? workMap['sourceId'] ?? '').toString();
        if (title.toLowerCase().contains(lowerQuery)) return true;
      } catch (_) {}
      // 也匹配音频名
      if (r.lastPlayedAudioName?.toLowerCase().contains(lowerQuery) == true) {
        return true;
      }
      return false;
    }).toList();
  }

  // ─── 内部方法 ───

  List<HistoryRecord> _loadAll() {
    try {
      final jsonStr = _prefs.getString(_recordsKey);
      if (jsonStr == null || jsonStr.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList
          .map((e) => HistoryRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.error('加载历史记录失败', e);
      return [];
    }
  }

  Future<void> _saveAll(List<HistoryRecord> records) async {
    final jsonList = records.map((r) => r.toJson()).toList();
    await _prefs.setString(_recordsKey, jsonEncode(jsonList));
  }

  /// 超过上限时裁剪最早记录
  Future<void> _trimIfNeeded() async {
    final records = _loadAll();
    final max = maxCount;
    if (records.length > max) {
      final trimmed = records.sublist(0, max);
      await _saveAll(trimmed);
      AppLogger.info('历史记录已裁剪: ${records.length} -> $max');
    }
  }

  /// 重建 Work 对象（从存储的 JSON 中）
  static Work? reconstructWork(HistoryRecord record) {
    try {
      final workMap = jsonDecode(record.workJson) as Map<String, dynamic>;
      return Work.fromJson(workMap);
    } catch (e) {
      AppLogger.error('重建Work对象失败', e);
      return null;
    }
  }
}