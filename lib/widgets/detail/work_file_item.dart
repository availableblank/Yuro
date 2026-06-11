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
    this.indentation = 0,
    this.onFileTap,
  });

  /// 通过文件名扩展名判断是否为文本文件
  bool _isTextByExtension(String filename) {
    final lower = filename.toLowerCase();
    return lower.endsWith('.txt') ||
        lower.endsWith('.tt') ||
        lower.endsWith('.lrc');
  }

  @override
  Widget build(BuildContext context) {
    final type = file.type?.toLowerCase();
    final fileName = file.title ?? '';
    final bool isAudio = type == 'audio';
    final bool isImage = type == 'image';
    // 通过扩展名识别文本文件（不依赖 type 字段）
    final bool isText = _isTextByExtension(fileName);
    final bool canTap = isAudio || isImage || isText;
    final colorScheme = Theme.of(context).colorScheme;

    // 根据文件类型选择图标和颜色
    final IconData leadingIcon;
    final Color? iconColor;
    if (isAudio) {
      leadingIcon = Icons.audio_file;
      iconColor = Colors.green;
    } else if (isImage) {
      leadingIcon = Icons.image;
      iconColor = Colors.orange;
    } else if (isText) {
      leadingIcon = Icons.description;
      iconColor = Colors.teal;
    } else {
      leadingIcon = Icons.insert_drive_file;
      iconColor = Colors.blue;
    }

    return Padding(
      padding: EdgeInsets.only(left: indentation),
      child: ListTile(
        title: Text(
          fileName,
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
                final label = isAudio
                    ? '音频'
                    : isImage
                        ? '图片'
                        : '文本';
                AppLogger.debug('点击$label文件: ${file.title}');
                onFileTap?.call(file);
              }
            : null,
      ),
    );
  }
}