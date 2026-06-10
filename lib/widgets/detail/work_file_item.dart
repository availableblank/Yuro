import 'package:flutter/material.dart';
import 'package:asmrapp/data/models/files/child.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/utils/file_size_formatter.dart';

class WorkFileItem extends StatelessWidget {
  final Child file;
  final double indentation;
  final Function(Child file)? onFileTap;

  const WorkFileItem({
    super.key,
    required this.file,
    required this.indentation,
    this.onFileTap,
  });

  /// 图片扩展名集合
  static const _imageExtensions = {
    'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif',
    'svg', 'heic', 'heif', 'tiff', 'tif', 'ico',
    'jfif', 'pjpeg', 'pjp', 'avif',
  };

  /// 从文件名的扩展名判断是否为图片
  static bool _isImageByExtension(String? filename) {
    if (filename == null || filename.isEmpty) return false;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex == -1) return false;
    final ext = filename.substring(dotIndex + 1).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  /// 判断是否为图片类型：
  /// 1. type 字段直接是扩展名（如 png/jpg）
  /// 2. type 字段是 'image'
  /// 3. 从文件名/标题推断
  static bool isImageType(String? type, {String? title}) {
    if (type == null || type.isEmpty) {
      // type 为空时，尝试从文件名判断
      return _isImageByExtension(title);
    }
    final lowerType = type.toLowerCase();
    // 直接是扩展名
    if (_imageExtensions.contains(lowerType)) return true;
    // 通用 image 类型
    if (lowerType == 'image') return true;
    // type 不匹配，但文件名扩展名匹配（兜底）
    return _isImageByExtension(title);
  }

  @override
  Widget build(BuildContext context) {
    final type = file.type?.toLowerCase();
    final bool isAudio = type == 'audio';
    final bool isImage = isImageType(type, title: file.title);
    final bool canTap = isAudio || isImage;
    final colorScheme = Theme.of(context).colorScheme;

    // 调试日志：确认实际 type 值和判断结果
    if (!isAudio && !isImage) {
      AppLogger.debug('非音频非图片文件: title=${file.title}, type=${file.type}');
    }

    IconData leadingIcon;
    Color? iconColor;
    if (isAudio) {
      leadingIcon = Icons.audio_file;
      iconColor = Colors.green;
    } else if (isImage) {
      leadingIcon = Icons.image;
      iconColor = Colors.orange;
    } else {
      leadingIcon = Icons.insert_drive_file;
      iconColor = Colors.blue;
    }

    return Padding(
      padding: EdgeInsets.only(left: indentation),
      child: ListTile(
        title: Text(
          file.title ?? '',
          style: TextStyle(color: colorScheme.onSurface),
        ),
        subtitle: Text(
          FileSizeFormatter.format(file.size),
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        leading: Icon(leadingIcon, color: iconColor),
        trailing: canTap
            ? Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant)
            : null,
        dense: true,
        onTap: canTap
            ? () {
                if (isAudio) {
                  AppLogger.debug('点击音频文件: ${file.title}');
                } else {
                  AppLogger.debug('点击图片文件: ${file.title}');
                }
                onFileTap?.call(file);
              }
            : null,
      ),
    );
  }
}