import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/core/cache/cache_settings.dart';

/// 列表缓存管理器
/// 将首页推荐、热门、搜索、作品详情等列表数据缓存到本地文件
/// 在网络不稳定时可切换为离线模式读取缓存
class ListCacheManager extends ChangeNotifier {
  static final ListCacheManager _instance = ListCacheManager._internal();
  factory ListCacheManager() => _instance;
  ListCacheManager._internal();

  static const String _cacheDirName = 'list_cache';
  static const Duration _cacheDuration = Duration(days: 7);
  static const String _toggleKey = 'use_local_cache_for_lists';
  static const int defaultLimitMb = 50;

  Directory? _cacheDir;
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

  /// 获取缓存目录
  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  /// 将缓存键转为安全文件名
  String _keyToFilename(String key) {
    final bytes = utf8.encode(key);
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// 读取缓存
  Future<Map<String, dynamic>?> get(String key) async {
    // 禁用时不读取
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
    // 禁用时不写入
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

      // 非无限模式下检查大小
      if (!_isUnlimited) {
        await _enforceSizeLimit();
      }
    } catch (e) {
      AppLogger.error('保存列表缓存失败: $key', e);
    }
  }

  /// 清除所有列表缓存
  Future<void> clear() async {
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _cacheDir = null;
      }
      AppLogger.debug('已清除所有列表缓存');
    } catch (e) {
      AppLogger.error('清除列表缓存失败', e);
    }
  }

  /// 获取列表缓存总大小（字节）
  Future<int> getSize() async {
    try {
      final dir = await _getCacheDir();
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      AppLogger.error('获取列表缓存大小失败', e);
      return 0;
    }
  }

  // ---- 私有 ----

  /// 按 MB 上限清理最旧文件
  Future<void> _enforceSizeLimit() async {
    try {
      final maxBytes = _limitMb * 1024 * 1024;
      final currentSize = await getSize();
      if (currentSize <= maxBytes) return;

      AppLogger.debug('列表缓存超出上限 (${_limitMb}MB)，开始清理...');

      final dir = await _getCacheDir();
      final files = <File>[];
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          files.add(entity);
        }
      }

      // 按修改时间升序（最旧的在前）
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      var remaining = currentSize;
      for (final file in files) {
        if (remaining <= maxBytes) break;
        final len = await file.length();
        await file.delete();
        remaining -= len;
        AppLogger.debug('删除超量列表缓存: ${file.path}');
      }
    } catch (e) {
      AppLogger.error('执行列表缓存大小限制失败', e);
    }
  }
}