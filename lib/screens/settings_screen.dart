import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/core/theme/theme_controller.dart';
import 'package:asmrapp/core/platform/wakelock_controller.dart';
import 'package:asmrapp/screens/settings/cache_manager_screen.dart';
import 'package:asmrapp/common/constants/strings.dart';
import 'package:asmrapp/data/repositories/history_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  IconData _getThemeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return Icons.brightness_auto;
      case ThemeMode.light:
        return Icons.brightness_high;
      case ThemeMode.dark:
        return Icons.brightness_2;
    }
  }

  String _getThemeText(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return '跟随系统主题';
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式';
    }
  }

  // 显示修改上限对话框
  Future<void> _showMaxHistoryDialog(BuildContext context) async {
    final repository = GetIt.I<HistoryRepository>();
    final controller = TextEditingController(text: repository.maxCount.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Strings.maxHistoryCount),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '上限条数',
            hintText: '例如：500',
            helperText: '设为 0 则不清除旧记录（不推荐）',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(Strings.cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value >= 0) {
                Navigator.pop(ctx, value);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('请输入有效数字')),
                );
              }
            },
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      await repository.setMaxCount(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('历史记录上限已设为 $result 条')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = GetIt.I<HistoryRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          Consumer<ThemeController>(
            builder: (context, themeController, _) {
              return ListTile(
                leading: Icon(_getThemeIcon(themeController.themeMode)),
                title: const Text('主题模式'),
                subtitle: Text(_getThemeText(themeController.themeMode)),
                onTap: () => themeController.toggleThemeMode(),
              );
            },
          ),
          ListenableBuilder(
            listenable: GetIt.I<WakeLockController>(),
            builder: (context, _) {
              final controller = GetIt.I<WakeLockController>();
              return SwitchListTile(
                title: const Text('屏幕常亮'),
                subtitle: const Text('播放时保持屏幕常亮'),
                value: controller.enabled,
                onChanged: (_) => controller.toggle(),
              );
            },
          ),
          const Divider(),
          // 历史记录上限设置
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text(Strings.maxHistoryCount),
            subtitle: Text(
              '当前上限：${repository.maxCount} 条\n${Strings.maxHistoryCountDesc}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showMaxHistoryDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('缓存管理'),
            subtitle: const Text('管理应用缓存数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CacheManagerScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}