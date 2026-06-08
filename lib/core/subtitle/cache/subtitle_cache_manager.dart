import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/core/cache/cache_settings.dart';

class SubtitleCacheManager {
  static const String key = 'subtitleCache';
  static const int defaultLimitMb = 50;

  static CacheSettings get _settings => GetIt.I<CacheSettings>();
  static int get _limitMb => _settings.subtitleLimitMb;
  static bool get _disabled => _settings.isSubtitleDisabled;
  static bool get _unlimited => _settings.isSubtitleUnlimited;

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );

  /// 获取缓存的字幕内容
  static Future<String?> getCachedContent(String url) async {
    try {
      // 禁用时不读取缓存
      if (_disabled) {
        return null;
      }
      final file = await instance.getSingleFile(url);
      AppLogger.debug('使用字幕缓存: $url');
      return await file.readAsString();
    } catch (e) {
      AppLogger.error('读取字幕缓存失败', e);
      return null;
    }
  }

  /// 保存字幕内容到缓存
  static Future<void> cacheContent(String url, String content) async {
    // 禁用时不写入
    if (_disabled) {
      return;
    }
    try {
      await instance.putFile(
        url,
        Uint8List.fromList(utf8.encode(content)),
        fileExtension: 'txt',
      );
      AppLogger.debug('字幕已缓存: $url');

      // 非无限模式下，写入后检查大小
      if (!_unlimited) {
        await _enforceSizeLimit();
      }
    } catch (e) {
      AppLogger.error('保存字幕缓存失败', e);
    }
  }

  /// 清理缓存
  static Future<void> clearCache() async {
    try {
      await instance.emptyCache();
      AppLogger.debug('字幕缓存已清空');
    } catch (e) {
      AppLogger.error('清理字幕缓存失败', e);
    }
  }

  /// 获取缓存大小（字节）
  static Future<int> getSize() async {
    try {
      return instance.store.getCacheSize();
    } catch (e) {
      AppLogger.error('获取字幕缓存大小失败', e);
      return 0;
    }
  }

  // ---- 私有 ----

  /// 按 MB 上限清理最旧文件
  static Future<void> _enforceSizeLimit() async {
    try {
      final maxBytes = _limitMb * 1024 * 1024;
      final currentSize = await getSize();
      if (currentSize <= maxBytes) return;

      AppLogger.debug('字幕缓存超出上限 (${_limitMb}MB)，开始清理...');

      // 通过 flutter_cache_manager 的 store 获取文件列表并手动清理
      // 简单策略：获取所有缓存文件，按修改时间排序，删除最旧的直到低于上限
      final cacheDir = await _getCacheDir();
      if (!await cacheDir.exists()) return;

      final files = await cacheDir
          .list()
          .where((e) => e is File)
          .map((e) => e as File)
          .toList();

      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));

      var remaining = currentSize;
      for (final file in files) {
        if (remaining <= maxBytes) break;
        final len = await file.length();
        await file.delete();
        remaining -= len;
        AppLogger.debug('删除超量字幕缓存: ${file.path}');
      }
    } catch (e) {
      AppLogger.error('执行字幕缓存大小限制失败', e);
    }
  }

  /// 获取缓存目录
  static Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    // flutter_cache_manager 默认存储在应用文档目录下的特定子目录
    return Directory('${appDir.path}/$key');
  }
}