import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asmrapp/utils/logger.dart';

/// 各缓存类型的独立上限配置
///
/// 数值含义：
///   - 正数 N：上限为 N MB，超出后自动清理最旧的数据
///   - 0：禁用该缓存，不写入也不读取
///   - -1：无上限，不自动清理
///
/// 默认值：
///   - 音频：500 MB
///   - 字幕： 50 MB
///   - 列表： 50 MB
///   - 推荐：1000 条（内存条目数，非 MB）
class CacheSettings extends ChangeNotifier {
  // ---- 存储 key ----
  static const String _kAudioLimit = 'cache_limit_audio_mb';
  static const String _kSubtitleLimit = 'cache_limit_subtitle_mb';
  static const String _kListLimit = 'cache_limit_list_mb';
  static const String _kRecommendationLimit = 'cache_limit_recommendation_entries';

  // ---- 默认值 ----
  static const int defaultAudioLimitMb = 500;
  static const int defaultSubtitleLimitMb = 50;
  static const int defaultListLimitMb = 50;
  static const int defaultRecommendationLimitEntries = 1000;

  final SharedPreferences _prefs;

  CacheSettings(this._prefs);

  // ========== 音频 ==========

  /// 音频缓存上限（MB）
  int get audioLimitMb => _prefs.getInt(_kAudioLimit) ?? defaultAudioLimitMb;

  Future<void> setAudioLimitMb(int value) async {
    await _prefs.setInt(_kAudioLimit, value);
    AppLogger.debug('音频缓存上限已设为: $value MB');
    notifyListeners();
  }

  /// 是否禁用音频缓存
  bool get isAudioDisabled => audioLimitMb == 0;

  /// 是否无上限
  bool get isAudioUnlimited => audioLimitMb < 0;

  // ========== 字幕 ==========

  int get subtitleLimitMb => _prefs.getInt(_kSubtitleLimit) ?? defaultSubtitleLimitMb;

  Future<void> setSubtitleLimitMb(int value) async {
    await _prefs.setInt(_kSubtitleLimit, value);
    AppLogger.debug('字幕缓存上限已设为: $value MB');
    notifyListeners();
  }

  bool get isSubtitleDisabled => subtitleLimitMb == 0;
  bool get isSubtitleUnlimited => subtitleLimitMb < 0;

  // ========== 列表 ==========

  int get listLimitMb => _prefs.getInt(_kListLimit) ?? defaultListLimitMb;

  Future<void> setListLimitMb(int value) async {
    await _prefs.setInt(_kListLimit, value);
    AppLogger.debug('列表缓存上限已设为: $value MB');
    notifyListeners();
  }

  bool get isListDisabled => listLimitMb == 0;
  bool get isListUnlimited => listLimitMb < 0;

  // ========== 推荐 ==========

  int get recommendationLimitEntries =>
      _prefs.getInt(_kRecommendationLimit) ?? defaultRecommendationLimitEntries;

  Future<void> setRecommendationLimitEntries(int value) async {
    await _prefs.setInt(_kRecommendationLimit, value);
    AppLogger.debug('推荐缓存上限已设为: $value 条');
    notifyListeners();
  }

  bool get isRecommendationDisabled => recommendationLimitEntries == 0;
  bool get isRecommendationUnlimited => recommendationLimitEntries < 0;
}