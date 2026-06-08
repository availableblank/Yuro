import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:just_audio/just_audio.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/core/cache/cache_settings.dart';

/// 音频缓存管理器
/// 管理音频文件的缓存
class AudioCacheManager {
  static const Duration _cacheExpiration = Duration(days: 30);

  /// 获取当前的 CacheSettings
  static CacheSettings get _settings => GetIt.I<CacheSettings>();

  // ---- 默认值（MB）----
  static const int defaultLimitMb = 500;

  // ---- 便捷取值 ----
  static int get _limitMb => _settings.audioLimitMb;
  static bool get _disabled => _settings.isAudioDisabled;
  static bool get _unlimited => _settings.isAudioUnlimited;

  /// 创建音频源
  /// 内部处理缓存逻辑
  static Future<AudioSource> createAudioSource(String url) async {
    try {
      // 0 = 禁用缓存：直接返回非缓存源
      if (_disabled) {
        AppLogger.debug('音频缓存已禁用，使用非缓存源');
        return ProgressiveAudioSource(Uri.parse(url));
      }

      final cacheFile = await _getCacheFile(url);
      final fileName = _generateFileName(url);
      AppLogger.debug('准备创建音频源 - URL: $url, 缓存文件名: $fileName');

      final isValid = await _isCacheValid(cacheFile, fileName);

      if (isValid) {
        AppLogger.debug('[$fileName] 使用已有缓存文件');
        return _createCachingSource(url, cacheFile);
      }

      AppLogger.debug('[$fileName] 创建新的缓存源');
      return _createCachingSource(url, cacheFile);
    } catch (e) {
      AppLogger.error('创建缓存音频源失败，使用非缓存源', e);
      return ProgressiveAudioSource(Uri.parse(url));
    }
  }

  /// 清理过期和超量的缓存
  static Future<void> cleanCache() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = await cacheDir.list().toList();

      // 按修改时间排序（旧 → 新）
      files.sort((a, b) {
        return a.statSync().modified.compareTo(b.statSync().modified);
      });

      var totalSize = 0;
      final maxBytes = _unlimited ? null : _limitMb * 1024 * 1024;

      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();

          // 检查是否过期
          if (DateTime.now().difference(stat.modified) > _cacheExpiration) {
            await file.delete();
            AppLogger.debug('删除过期音频缓存: ${file.path}');
            continue;
          }

          totalSize += stat.size;

          // -1 时不限制总量，仅删除过期文件
          if (!_unlimited && maxBytes != null && totalSize > maxBytes) {
            await file.delete();
            AppLogger.debug('删除超量音频缓存: ${file.path}');
          }
        }
      }
    } catch (e) {
      AppLogger.error('清理缓存失败', e);
    }
  }

  /// 获取缓存大小（字节）
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = await cacheDir.list().toList();

      var totalSize = 0;
      for (var file in files) {
        if (file is File) {
          totalSize += (await file.stat()).size;
        }
      }
      return totalSize;
    } catch (e) {
      AppLogger.error('获取缓存大小失败', e);
      return 0;
    }
  }

  // ---- 私有方法 ----

  static AudioSource _createCachingSource(String url, File cacheFile) {
    return LockCachingAudioSource(Uri.parse(url), cacheFile: cacheFile);
  }

  static Future<bool> _isCacheValid(File cacheFile, String fileName) async {
    final exists = await cacheFile.exists();
    if (!exists) {
      AppLogger.debug('[$fileName] 缓存验证: 文件不存在');
      return false;
    }

    try {
      final stat = await cacheFile.stat();
      final age = DateTime.now().difference(stat.modified);

      AppLogger.debug('[$fileName] 缓存验证: 大小=${stat.size}bytes, 年龄=$age');

      if (age > _cacheExpiration) {
        AppLogger.debug('[$fileName] 缓存无效: 文件过期 ($age > $_cacheExpiration)');
        await cacheFile.delete();
        return false;
      }

      AppLogger.debug('[$fileName] 缓存验证: 有效');
      return true;
    } catch (e) {
      AppLogger.error('[$fileName] 检查缓存有效性失败', e);
      return false;
    }
  }

  static Future<File> _getCacheFile(String url) async {
    final cacheDir = await _getCacheDir();
    final fileName = _generateFileName(url);
    return File('${cacheDir.path}/$fileName');
  }

  static String _generateFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  static Future<Directory> _getCacheDir() async {
    final cacheDir = await getTemporaryDirectory();
    final audioCacheDir = Directory('${cacheDir.path}/audio_cache');
    if (!await audioCacheDir.exists()) {
      await audioCacheDir.create(recursive: true);
    }
    return audioCacheDir;
  }
}