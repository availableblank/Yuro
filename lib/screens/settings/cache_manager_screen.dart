import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:asmrapp/presentation/viewmodels/settings/cache_manager_viewmodel.dart';

class CacheManagerScreen extends StatelessWidget {
  const CacheManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CacheManagerViewModel()..loadCacheSize(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('缓存管理'),
        ),
        body: Consumer<CacheManagerViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.error != null) {
              return Center(
                child: Text(
                  viewModel.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }

            return ListView(
              children: [
                // 音频缓存
                ListTile(
                  title: const Text('音频缓存'),
                  subtitle: Text(viewModel.audioCacheSizeFormatted),
                  trailing: TextButton(
                    onPressed: viewModel.isLoading 
                      ? null 
                      : () => viewModel.clearAudioCache(),
                    child: const Text('清理'),
                  ),
                ),
                const Divider(),
                
                // 字幕缓存
                ListTile(
                  title: const Text('字幕缓存'),
                  subtitle: Text(viewModel.subtitleCacheSizeFormatted),
                  trailing: TextButton(
                    onPressed: viewModel.isLoading 
                      ? null 
                      : () => viewModel.clearSubtitleCache(),
                    child: const Text('清理'),
                  ),
                ),
                const Divider(),

                // 列表缓存
                ListTile(
                  title: const Text('列表缓存'),
                  subtitle: Text(viewModel.listCacheSizeFormatted),
                  trailing: TextButton(
                    onPressed: viewModel.isLoading 
                      ? null 
                      : () => viewModel.clearListCache(),
                    child: const Text('清理'),
                  ),
                ),
                const Divider(),
                
                // 总缓存大小
                ListTile(
                  title: const Text('总缓存大小'),
                  subtitle: Text(viewModel.totalCacheSizeFormatted),
                  trailing: TextButton(
                    onPressed: viewModel.isLoading 
                      ? null 
                      : () => viewModel.clearAllCache(),
                    child: const Text('清理全部'),
                  ),
                ),
                const Divider(),
                
                // 缓存说明
                const ListTile(
                  title: Text('缓存说明'),
                  subtitle: Text(
                    '音频缓存：存储最近播放的音频文件。\n'
                    '字幕缓存：存储最近加载的字幕文件。\n'
                    '列表缓存：存储首页推荐、搜索结果、热门列表、作品详情等数据，'
                    '开启侧边栏的「使用本地缓存加载列表」后，可在网络不稳定时离线浏览。\n'
                    '系统会自动清理过期和超量的缓存。'
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}