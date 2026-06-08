import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/core/audio/cache/audio_cache_manager.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/core/subtitle/cache/subtitle_cache_manager.dart';
import 'package:asmrapp/core/cache/list_cache_manager.dart';
import 'package:asmrapp/core/cache/cache_settings.dart';
import 'package:asmrapp/core/cache/recommendation_cache_manager.dart';

class CacheManagerViewModel extends ChangeNotifier {
  bool _isLoading = false;
  int _audioCacheSize = 0;
  int _subtitleCacheSize = 0;
  int _listCacheSize = 0;
  int _recommendationEntryCount = 0;
  String? _error;

  // ---- CacheSettings 引用 ----
  CacheSettings get _settings => GetIt.I<CacheSettings>();

  bool get isLoading => _isLoading;
  int get audioCacheSize => _audioCacheSize;
  int get subtitleCacheSize => _subtitleCacheSize;
  int get listCacheSize => _listCacheSize;
  int get recommendationEntryCount => _recommendationEntryCount;
  int get totalCacheSize =>
      _audioCacheSize + _subtitleCacheSize + _listCacheSize;
  String? get error => _error;

  // ---- 各缓存上限（MB，推荐为条目数）----
  int get audioLimitMb => _settings.audioLimitMb;
  int get subtitleLimitMb => _settings.subtitleLimitMb;
  int get listLimitMb => _settings.listLimitMb;
  int get recommendationLimitEntries => _settings.recommendationLimitEntries;

  // ---- 便捷判断 ----
  bool get isAudioDisabled => _settings.isAudioDisabled;
  bool get isAudioUnlimited => _settings.isAudioUnlimited;
  bool get isSubtitleDisabled => _settings.isSubtitleDisabled;
  bool get isSubtitleUnlimited => _settings.isSubtitleUnlimited;
  bool get isListDisabled => _settings.isListDisabled;
  bool get isListUnlimited => _settings.isListUnlimited;
  bool get isRecommendationDisabled => _settings.isRecommendationDisabled;
  bool get isRecommendationUnlimited => _settings.isRecommendationUnlimited;

  String _formatSize(int size) {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)}MB';
  }

  /// 格式化上限值用于 UI 显示
  String formatLimit(int limitMb) {
    if (limitMb == 0) return '已禁用';
    if (limitMb < 0) return '无上限';
    return '${limitMb}MB';
  }

  String get audioCacheSizeFormatted => _formatSize(_audioCacheSize);
  String get subtitleCacheSizeFormatted => _formatSize(_subtitleCacheSize);
  String get listCacheSizeFormatted => _formatSize(_listCacheSize);
  String get totalCacheSizeFormatted => _formatSize(totalCacheSize);

  String get audioLimitFormatted => formatLimit(audioLimitMb);
  String get subtitleLimitFormatted => formatLimit(subtitleLimitMb);
  String get listLimitFormatted => formatLimit(listLimitMb);
  String get recommendationLimitFormatted =>
      recommendationLimitEntries == 0
          ? '已禁用'
          : recommendationLimitEntries < 0
              ? '无上限'
              : '${recommendationLimitEntries}条';

  // ========== 设置上限 ==========

  Future<void> setAudioLimit(int value) async {
    await _settings.setAudioLimitMb(value);
    notifyListeners();
    // 若设为 0（禁用），立即清理
    if (value == 0) {
      await clearAudioCache();
    }
  }

  Future<void> setSubtitleLimit(int value) async {
    await _settings.setSubtitleLimitMb(value);
    notifyListeners();
    if (value == 0) {
      await clearSubtitleCache();
    }
  }

  Future<void> setListLimit(int value) async {
    await _settings.setListLimitMb(value);
    notifyListeners();
    if (value == 0) {
      await clearListCache();
    }
  }

  Future<void> setRecommendationLimit(int value) async {
    await _settings.setRecommendationLimitEntries(value);
    notifyListeners();
    if (value == 0) {
      RecommendationCacheManager().clear();
      await loadCacheSize();
    }
  }

  // ========== 加载大小 ==========

  Future<void> loadCacheSize() async {
    try {
      _isLoading = true;
      notifyListeners();

      _audioCacheSize = await AudioCacheManager.getCacheSize();
      _subtitleCacheSize = await SubtitleCacheManager.getSize();
      _listCacheSize = await ListCacheManager().getSize();
      _recommendationEntryCount = RecommendationCacheManager().entryCount;

      _error = null;
    } catch (e) {
      AppLogger.error('加载缓存大小失败', e);
      _error = '加载失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ========== 清理 ==========

  Future<void> clearAudioCache() async {
    try {
      _isLoading = true;
      notifyListeners();
      await AudioCacheManager.cleanCache();
      await loadCacheSize();
      _error = null;
    } catch (e) {
      AppLogger.error('清理音频缓存失败', e);
      _error = '清理失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSubtitleCache() async {
    try {
      _isLoading = true;
      notifyListeners();
      await SubtitleCacheManager.clearCache();
      await loadCacheSize();
      _error = null;
    } catch (e) {
      AppLogger.error('清理字幕缓存失败', e);
      _error = '清理失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearListCache() async {
    try {
      _isLoading = true;
      notifyListeners();
      await ListCacheManager().clear();
      await loadCacheSize();
      _error = null;
    } catch (e) {
      AppLogger.error('清理列表缓存失败', e);
      _error = '清理失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearRecommendationCache() async {
    try {
      _isLoading = true;
      notifyListeners();
      RecommendationCacheManager().clear();
      await loadCacheSize();
      _error = null;
    } catch (e) {
      AppLogger.error('清理推荐缓存失败', e);
      _error = '清理失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearAllCache() async {
    try {
      _isLoading = true;
      notifyListeners();
      await Future.wait([
        AudioCacheManager.cleanCache(),
        SubtitleCacheManager.clearCache(),
        ListCacheManager().clear(),
      ]);
      RecommendationCacheManager().clear();
      await loadCacheSize();
      _error = null;
    } catch (e) {
      AppLogger.error('清理缓存失败', e);
      _error = '清理失败: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}