import 'package:flutter/material.dart';
import 'package:asmrapp/data/models/files/child.dart';
import 'package:asmrapp/widgets/detail/work_folder_item.dart';
import 'package:asmrapp/widgets/detail/work_file_item.dart';

class WorkFilesList extends StatelessWidget {
  final List<Child>? children;
  final String currentPath;
  final bool canNavigateUp;
  final VoidCallback onNavigateUp;
  final Function(Child folder) onFolderTap;
  final Function(Child file)? onFileTap;

  const WorkFilesList({
    super.key,
    required this.children,
    required this.currentPath,
    required this.canNavigateUp,
    required this.onNavigateUp,
    required this.onFolderTap,
    this.onFileTap,
  });

  /// 路径过长时从开头开始省略，保留结尾
  String _formatPathForDisplay(String path) {
    const maxChars = 36;
    if (path.length <= maxChars) return path;
    // 使用 Unicode 省略号 …
    return '\u2026${path.substring(path.length - maxChars + 1)}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '文件列表',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPathForDisplay(currentPath),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.surfaceVariant,
          ),
          // 非根目录时显示 ".." 返回上级
          if (canNavigateUp)
            ListTile(
              leading: Icon(
                Icons.folder_open,
                color: colorScheme.primary,
              ),
              title: Text(
                '..',
                style: TextStyle(color: colorScheme.onSurface),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
              dense: true,
              onTap: onNavigateUp,
            ),
          // 当前层级的文件夹和文件
          ...?children?.map((child) {
                if (child.type?.toLowerCase() == 'folder') {
                  return WorkFolderItem(
                    folder: child,
                    onTap: () => onFolderTap(child),
                  );
                } else {
                  return WorkFileItem(
                    file: child,
                    onFileTap: onFileTap,
                  );
                }
              }) ??
              [],
          // 空目录提示
          if (children == null || children!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  '此目录为空',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}