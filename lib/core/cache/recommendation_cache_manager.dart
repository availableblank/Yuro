import 'dart:collection';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/data/services/api_service.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/core/cache/cache_settings.dart';

class RecommendationCacheManager {
  static final RecommendationCacheManager _instance =
      RecommendationCacheManager._internal();
  factory RecommendationCacheManager() => _instance;
  RecommendationCacheManager._internal();

  final _cache = LinkedHashMap<String, _CacheItem>();

  static const Duration _cacheDuration = Duration(hours: 24);
  static const int defaultLimitEntries = 1000;

  // ---- 便捷取值 ----
  CacheSettings get _settings => GetIt.I<CacheSettings>();
  int get _maxCacheSize => _settings.recommendationLimitEntries;
  bool get _isDisabled => _settings.isRecommendationDisabled;
  bool get _isUnlimited => _settings.isRecommendationUnlimited;

  String _generateKey(String itemId, int page, int subtitle) {
    return '$itemId-$page-$subtitle';
  }

  /// 获取缓存数据
  WorksResponse? get(String itemId, int page, int subtitle) {
    // 禁用时不返回缓存
    if (_isDisabled) return null;

    final key = _generateKey(itemId, page, subtitle);
    final item = _cache[key];

    if (item == null) return null;

    if (item.isExpired) {
      _cache.remove(key);
      AppLogger.debug('缓存已过期: $key');
      return null;
    }

    AppLogger.debug('命中缓存: $key');
    return item.data;
  }

  /// 存储缓存数据
  void set(String itemId, int page, int subtitle, WorksResponse data) {
    // 禁用时不写入
    if (_isDisabled) return;

    final key = _generateKey(itemId, page, subtitle);

    // 非无限模式下检查条目数
    if (!_isUnlimited && _cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = _CacheItem(data);
    AppLogger.debug('添加缓存: $key');
  }

  /// 清除所有缓存
  void clear() {
    _cache.clear();
    AppLogger.debug('清除所有推荐缓存');
  }

  /// 移除指定作品的缓存
  void remove(String itemId) {
    _cache.removeWhere((key, _) => key.startsWith('$itemId-'));
    AppLogger.debug('移除作品缓存: $itemId');
  }

  /// 当前缓存条目数
  int get entryCount => _cache.length;
}

class _CacheItem {
  final WorksResponse data;
  final DateTime timestamp;

  _CacheItem(this.data) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp) >
      RecommendationCacheManager._cacheDuration;
}