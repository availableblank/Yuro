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

  @override
  Widget build(BuildContext context) {
    final type = file.type?.toLowerCase();
    final bool isAudio = type == 'audio';
    final bool isImage = type == 'image';
    final bool canTap = isAudio || isImage;
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
                AppLogger.debug('点击${isAudio ? "音频" : "图片"}文件: ${file.title}');
                onFileTap?.call(file);
              }
            : null,
      ),
    );
  }
}