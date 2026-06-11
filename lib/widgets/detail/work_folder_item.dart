import 'package:flutter/material.dart';
import 'package:asmrapp/data/models/files/child.dart';

class WorkFolderItem extends StatelessWidget {
  final Child folder;
  final VoidCallback onTap;

  const WorkFolderItem({
    super.key,
    required this.folder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      title: Text(
        folder.title ?? '',
        style: TextStyle(color: colorScheme.onSurface),
      ),
      leading: Icon(
        Icons.folder,
        color: colorScheme.primary,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      dense: true,
      onTap: onTap,
    );
  }
}