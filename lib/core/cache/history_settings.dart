import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理历史记录相关的设置项（如最大条数上限）
class HistorySettings extends ChangeNotifier {
  static const _keyMaxCount = 'history_max_count';
  static const int defaultMaxCount = 500;

  final SharedPreferences _prefs;

  HistorySettings(this._prefs) {
    // 确保默认值已写入
    if (_prefs.getInt(_keyMaxCount) == null) {
      _prefs.setInt(_keyMaxCount, defaultMaxCount);
    }
  }

  int get maxCount => _prefs.getInt(_keyMaxCount) ?? defaultMaxCount;

  Future<void> setMaxCount(int count) async {
    if (count < 20) count = 20; // 最低 20 条
    await _prefs.setInt(_keyMaxCount, count);
    notifyListeners();
  }

  /// 重置为默认值
  Future<void> resetToDefault() async {
    await _prefs.setInt(_keyMaxCount, defaultMaxCount);
    notifyListeners();
  }
}