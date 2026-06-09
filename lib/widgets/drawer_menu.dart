import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:asmrapp/common/constants/strings.dart';
import 'package:asmrapp/presentation/viewmodels/auth_viewmodel.dart';
import 'package:asmrapp/presentation/widgets/auth/login_dialog.dart';
import 'package:asmrapp/screens/favorites_screen.dart';
import 'package:asmrapp/screens/settings/cache_manager_screen.dart';
import 'package:asmrapp/core/theme/theme_controller.dart';
import 'package:asmrapp/core/platform/wakelock_controller.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/core/cache/list_cache_manager.dart';
import 'package:asmrapp/screens/settings_screen.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  /// 显示登录对话框（需传入有效的 NavigatorState，而非已失效的 context）
  void _showLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const LoginDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: ListTileTheme(
        style: ListTileStyle.drawer,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Theme(
              data: Theme.of(context).copyWith(
                dividerTheme: const DividerThemeData(color: Colors.transparent),
              ),
              child: const DrawerHeader(
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                ),
                child: Text(
                  Strings.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
            Consumer<AuthViewModel>(
              builder: (context, authVM, _) {
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(
                    authVM.isLoggedIn ? authVM.username ?? '' : '登录',
                  ),
                  onTap: () {
                    // 登录/登出不涉及页面跳转，直接 pop 即可
                    Navigator.pop(context);
                    if (authVM.isLoggedIn) {
                      authVM.logout();
                    } else {
                      // pop 后 context 可能失效，但这里 _showLoginDialog 内部
                      // 会通过 showDialog 自行查找 Navigator
                      _showLoginDialog(context);
                    }
                  },
                );
              },
            ),


            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text(Strings.favorites),
              onTap: () {
                // ★ 关键：先获取 NavigatorState 引用
                final navigator = Navigator.of(context);
                final authVM = context.read<AuthViewModel>();
                navigator.pop(); // 关闭侧边栏

                if (!authVM.isLoggedIn) {
                  // 使用 navigator.context（始终有效）显示登录对话框
                  showDialog(
                    context: navigator.context,
                    builder: (ctx) => const LoginDialog(),
                  );
                  return;
                }
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => const FavoritesScreen(),
                  ),
                );
              },
            ),


            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text(Strings.settings),
              onTap: () {
                // ★ 关键：先获取 NavigatorState 引用，再 pop
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
            ),


            ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('缓存管理'),
              onTap: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => const CacheManagerScreen(),
                  ),
                );
              },
            ),

            Divider(
              color: Theme.of(context).colorScheme.surfaceVariant,
              height: 1,
            ),
            Consumer<ThemeController>(
              builder: (context, themeController, _) {
                return ListTile(
                  leading: Icon(_getThemeIcon(themeController.themeMode)),
                  title: Text(_getThemeText(themeController.themeMode)),
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
                  value: controller.enabled,
                  onChanged: (_) => controller.toggle(),
                );
              },
            ),
            const Divider(),
            ListenableBuilder(
              listenable: GetIt.I<ListCacheManager>(),
              builder: (context, _) {
                final cacheManager = GetIt.I<ListCacheManager>();
                return SwitchListTile(
                  title: const Text('使用本地缓存加载列表'),
                  subtitle: const Text('开启后优先从本地缓存加载列表数据，适合网络不稳定时使用'),
                  value: cacheManager.enabled,
                  onChanged: (_) => cacheManager.toggle(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
}