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

  /// 判断是否为图片类型（基于文件扩展名）
  static bool isImageType(String? type) {
    if (type == null || type.isEmpty) return false;
    const imageExtensions = {
      'png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif',
      'svg', 'heic', 'heif', 'tiff', 'tif', 'ico',
      'jfif', 'pjpeg', 'pjp', 'avif',
    };
    return imageExtensions.contains(type.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final type = file.type?.toLowerCase();
    final bool isAudio = type == 'audio';
    final bool isImage = isImageType(type);
    final bool canTap = isAudio || isImage;
    final colorScheme = Theme.of(context).colorScheme;

    // 根据文件类型选择图标和颜色
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