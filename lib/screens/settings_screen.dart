import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/core/theme/theme_controller.dart';
import 'package:asmrapp/core/platform/wakelock_controller.dart';
import 'package:asmrapp/screens/settings/cache_manager_screen.dart';

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
        ],
      ),
    );
  }
}