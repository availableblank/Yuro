import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/core/theme/theme_controller.dart';
import 'package:asmrapp/core/platform/wakelock_controller.dart';
import 'package:asmrapp/screens/settings/cache_manager_screen.dart';
import 'package:asmrapp/core/cache/history_settings.dart';

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

  @override
  Widget build(BuildContext context) {
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

          // 历史记录上限设置
          const Divider(),
          ListenableBuilder(
            listenable: GetIt.I<HistorySettings>(),
            builder: (context, _) {
              final settings = GetIt.I<HistorySettings>();
              return ListTile(
                leading: const Icon(Icons.history),
                title: const Text('历史记录上限'),
                subtitle: Text('当前上限：${settings.maxCount} 条'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: settings.maxCount > 20
                          ? () => settings.setMaxCount(settings.maxCount - 100)
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: settings.maxCount < 2000
                          ? () => settings.setMaxCount(settings.maxCount + 100)
                          : null,
                    ),
                  ],
                ),
                onTap: () {
                  // 弹窗逻辑内联
                  final controller = TextEditingController(
                    text: settings.maxCount.toString(),
                  );
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('历史记录上限'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '最大条数',
                          hintText: '20~2000',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () {
                            final count = int.tryParse(controller.text);
                            if (count != null) {
                              settings.setMaxCount(count);
                            }
                            Navigator.pop(ctx);
                          },
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}