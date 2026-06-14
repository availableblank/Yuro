import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/core/cache/cache_settings.dart';

/// 列表缓存管理器
/// 将首页推荐、热门、搜索、作品详情等列表数据缓存到本地文件，
/// 同时将 CachedNetworkImage 的图片缓存(作品封面)一并纳入列表缓存上限管理。
/// 在网络不稳定时可切换为离线模式读取缓存。
class ListCacheManager extends ChangeNotifier {
  static final ListCacheManager _instance = ListCacheManager._internal();
  factory ListCacheManager() => _instance;
  ListCacheManager._internal();

  static const String _cacheDirName = 'list_cache';
  static const Duration _cacheDuration = Duration(days: 7);
  static const String _toggleKey = 'use_local_cache_for_lists';
  static const int defaultLimitMb = 50;
  /// flutter_cache_manager 默认的图片缓存子目录名
  static const String _imageCacheDirName = 'libCachedImageData';

  Directory? _cacheDir;
  Directory? _imageCacheDir;
  bool _enabled = false;

  // ---- 便捷取值 ----
  CacheSettings get _settings => GetIt.I<CacheSettings>();
  int get _limitMb => _settings.listLimitMb;
  bool get _isDisabled => _settings.isListDisabled;
  bool get _isUnlimited => _settings.isListUnlimited;

  /// 是否启用「使用本地缓存加载列表」
  bool get enabled => _enabled;

  /// 切换启用状态
  Future<void> toggle() async {
    _enabled = !_enabled;
    try {
      final dir = await _getCacheDir();
      final flagFile = File('${dir.parent.path}/$_toggleKey');
      await flagFile.writeAsString(_enabled ? '1' : '0');
    } catch (e) {
      AppLogger.error('保存列表缓存开关状态失败', e);
    }
    notifyListeners();
  }

  /// 从磁盘加载开关状态
  Future<void> loadToggleState() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final flagFile = File('${appDir.path}/$_toggleKey');
      if (await flagFile.exists()) {
        _enabled = await flagFile.readAsString() == '1';
      }
    } catch (e) {
      _enabled = false;
    }
  }

  // ========== 目录获取 ==========

  /// 获取 JSON 缓存目录
  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  /// 获取图片缓存目录（DefaultCacheManager 默认使用的目录）
  Future<Directory> _getImageCacheDir() async {
    if (_imageCacheDir != null) return _imageCacheDir!;
    final tempDir = await getTemporaryDirectory();
    _imageCacheDir = Directory('${tempDir.path}/$_imageCacheDirName');
    return _imageCacheDir!;
  }

  // ========== 缓存键编码 ==========

  /// 将缓存键转为安全文件名
  String _keyToFilename(String key) {
    final bytes = utf8.encode(key);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  // ========== JSON 缓存读写 ==========

  /// 读取缓存
  Future<Map<String, dynamic>?> get(String key) async {
    if (_isDisabled) return null;

    try {
      final dir = await _getCacheDir();
      final filename = _keyToFilename(key);
      final file = File('${dir.path}/$filename.json');

      if (!await file.exists()) return null;

      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;

      final timestampStr = json['timestamp'] as String?;
      if (timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        if (DateTime.now().difference(timestamp) > _cacheDuration) {
          await file.delete();
          AppLogger.debug('列表缓存已过期: $key');
          return null;
        }
      }

      AppLogger.debug('命中列表缓存: $key');
      return json['data'] as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.error('读取列表缓存失败: $key', e);
      return null;
    }
  }

  /// 写入缓存
  Future<void> set(String key, Map<String, dynamic> data) async {
    if (_isDisabled) return;

    try {
      final dir = await _getCacheDir();
      final filename = _keyToFilename(key);
      final file = File('${dir.path}/$filename.json');

      final json = {
        'timestamp': DateTime.now().toIso8601String(),
        'key': key,
        'data': data,
      };

      await file.writeAsString(jsonEncode(json));
      AppLogger.debug('保存列表缓存: $key');

      // 非无限模式下检查缓存上限（JSON + 图片合计）
      if (!_isUnlimited) {
        await _enforceSizeLimit();
      }
    } catch (e) {
      AppLogger.error('保存列表缓存失败: $key', e);
    }
  }

  // ========== 清理 ==========

  /// 清除所有列表缓存（JSON + 图片）
  Future<void> clear() async {
    try {
      // 清除 JSON 缓存
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _cacheDir = null;
      }

      // 清除图片缓存（通过 flutter_cache_manager 的 API）
      await DefaultCacheManager().emptyCache();
      _imageCacheDir = null;

      AppLogger.debug('已清除所有列表缓存（含图片缓存）');
    } catch (e) {
      AppLogger.error('清除列表缓存失败', e);
    }
  }

  // ========== 大小统计 ==========

  /// 获取列表缓存总大小（JSON + 图片，单位：字节）
  Future<int> getSize() async {
    try {
      int totalSize = 0;

      // JSON 缓存
      final jsonDir = await _getCacheDir();
      if (await jsonDir.exists()) {
        await for (final entity in jsonDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            totalSize += await entity.length();
          }
        }
      }

      // 封面缓存
      totalSize += await _getImageCacheFileSize();

      return totalSize;
    } catch (e) {
      AppLogger.error('获取列表缓存大小失败', e);
      return 0;
    }
  }

  /// 获取封面缓存大小（单位：字节）
  Future<int> getImageCacheSize() async {
    try {
      return await _getImageCacheFileSize();
    } catch (e) {
      AppLogger.error('获取封面缓存大小失败', e);
      return 0;
    }
  }

  /// 读取封面缓存目录下所有非数据库文件的总大小
  Future<int> _getImageCacheFileSize() async {
    final imageDir = await _getImageCacheDir();
    if (!await imageDir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in imageDir.list(recursive: true)) {
      if (entity is File && !_isDatabaseFile(entity)) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  // ========== 上限强制 ==========

  /// 强制执行缓存大小限制（合并 JSON 和图片缓存，按最旧优先清理）
  /// 可在设置页面手动调用，或由 [set] 自动触发
  Future<void> enforceSizeLimit() async {
    await _enforceSizeLimit();
  }

  // ---- 私有 ----

  /// 判断是否为 flutter_cache_manager 的数据库文件
  bool _isDatabaseFile(File file) {
    final name = file.path.split(Platform.pathSeparator).last;
    return name == 'cache.db' ||
        name == 'cache.db-shm' ||
        name == 'cache.db-wal';
  }

  /// 按 MB 上限清理最旧文件（JSON + 图片统一排序）
  Future<void> _enforceSizeLimit() async {
    try {
      final maxBytes = _limitMb * 1024 * 1024;
      final currentSize = await getSize();
      if (currentSize <= maxBytes) return;

      AppLogger.debug(
          '列表缓存超出上限 (${_limitMb}MB)，当前: ${(currentSize / 1024 / 1024).toStringAsFixed(1)}MB，开始清理（含图片）...');

      // 收集所有可清理的文件
      final files = <File>[];

      // JSON 缓存文件
      final jsonDir = await _getCacheDir();
      if (await jsonDir.exists()) {
        await for (final entity in jsonDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            files.add(entity);
          }
        }
      }

      // 封面缓存文件（排除数据库文件）
      final imageDir = await _getImageCacheDir();
      if (await imageDir.exists()) {
        await for (final entity in imageDir.list(recursive: true)) {
          if (entity is File && !_isDatabaseFile(entity)) {
            files.add(entity);
          }
        }
      }

      // 按修改时间升序（最旧的在前）
      files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      var remaining = currentSize;
      for (final file in files) {
        if (remaining <= maxBytes) break;
        final len = await file.length();
        await file.delete();
        remaining -= len;
        AppLogger.debug('删除超量缓存: ${file.path.split(Platform.pathSeparator).last}');
      }

      AppLogger.debug(
          '缓存清理完成，剩余: ${(remaining / 1024 / 1024).toStringAsFixed(1)}MB');
    } catch (e) {
      AppLogger.error('执行列表缓存大小限制失败', e);
    }
  }
}