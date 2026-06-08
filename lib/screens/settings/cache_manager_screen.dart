import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:asmrapp/presentation/viewmodels/settings/cache_manager_viewmodel.dart';

class CacheManagerScreen extends StatelessWidget {
  const CacheManagerScreen({super.key});

  /// 弹出输入对话框，让用户输入新的上限值（MB 整数）
  Future<void> _showLimitDialog({
    required BuildContext context,
    required String title,
    required int currentValue,
    required String hint,
    required ValueChanged<int> onSaved,
  }) async {
    final controller = TextEditingController(
      text: currentValue.toString(),
    );
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设置$title上限'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            ],
            decoration: InputDecoration(
              hintText: hint,
              helperText: '正数=上限(MB)，0=禁用，-1=无上限',
              helperMaxLines: 2,
            ),
            autofocus: true,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '请输入一个整数';
              final parsed = int.tryParse(v.trim());
              if (parsed == null) return '请输入有效的整数';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, int.parse(controller.text.trim()));
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null) {
      onSaved(result);
    }
  }

  /// 格式化数值为可读字符串
  String _formatLimitText(int value, {bool isEntry = false}) {
    if (value == 0) return '已禁用';
    if (value < 0) return '无上限';
    return isEntry ? '$value 条' : '${value}MB';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CacheManagerViewModel()..loadCacheSize(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('缓存管理'),
        ),
        body: Consumer<CacheManagerViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.error != null) {
              return Center(
                child: Text(
                  vm.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              );
            }

            return ListView(
              children: [
                // ===== 音频缓存 =====
                _CacheSection(
                  icon: Icons.music_note,
                  title: '音频缓存',
                  description: '最近播放的音频文件',
                  currentSize: vm.audioCacheSize,
                  limitMb: vm.audioLimitMb,
                  sizeFormatted: vm.audioCacheSizeFormatted,
                  limitFormatted: vm.audioLimitFormatted,
                  onClear: () => vm.clearAudioCache(),
                  onEditLimit: () => _showLimitDialog(
                    context: context,
                    title: '音频缓存',
                    currentValue: vm.audioLimitMb,
                    hint: '默认500MB',
                    onSaved: (v) => vm.setAudioLimit(v),
                  ),
                ),

                // ===== 字幕缓存 =====
                _CacheSection(
                  icon: Icons.subtitles,
                  title: '字幕缓存',
                  description: '最近加载的字幕文件',
                  currentSize: vm.subtitleCacheSize,
                  limitMb: vm.subtitleLimitMb,
                  sizeFormatted: vm.subtitleCacheSizeFormatted,
                  limitFormatted: vm.subtitleLimitFormatted,
                  onClear: () => vm.clearSubtitleCache(),
                  onEditLimit: () => _showLimitDialog(
                    context: context,
                    title: '字幕缓存',
                    currentValue: vm.subtitleLimitMb,
                    hint: '默认50MB',
                    onSaved: (v) => vm.setSubtitleLimit(v),
                  ),
                ),

                // ===== 列表缓存 =====
                _CacheSection(
                  icon: Icons.list_alt,
                  title: '列表缓存',
                  description: '推荐、热门、搜索等列表数据',
                  currentSize: vm.listCacheSize,
                  limitMb: vm.listLimitMb,
                  sizeFormatted: vm.listCacheSizeFormatted,
                  limitFormatted: vm.listLimitFormatted,
                  onClear: () => vm.clearListCache(),
                  onEditLimit: () => _showLimitDialog(
                    context: context,
                    title: '列表缓存',
                    currentValue: vm.listLimitMb,
                    hint: '默认50MB',
                    onSaved: (v) => vm.setListLimit(v),
                  ),
                ),

                // ===== 推荐缓存（条目） =====
                ListTile(
                  leading: const Icon(Icons.recommend),
                  title: const Text('推荐缓存'),
                  subtitle: Text(
                    '${vm.recommendationEntryCount} 条 / ${vm.recommendationLimitFormatted}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: vm.isLoading
                            ? null
                            : () => vm.clearRecommendationCache(),
                        child: const Text('清理'),
                      ),
                      TextButton(
                        onPressed: () => _showLimitDialog(
                          context: context,
                          title: '推荐缓存',
                          currentValue: vm.recommendationLimitEntries,
                          hint: '默认1000条',
                          onSaved: (v) => vm.setRecommendationLimit(v),
                        ),
                        child: const Text('上限'),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // ===== 总缓存 =====
                ListTile(
                  leading: const Icon(Icons.storage),
                  title: const Text('总缓存大小'),
                  subtitle: Text(vm.totalCacheSizeFormatted),
                  trailing: TextButton(
                    onPressed:
                        vm.isLoading ? null : () => vm.clearAllCache(),
                    child: const Text('清理全部'),
                  ),
                ),
                const Divider(),

                // ===== 说明 =====
                const ListTile(
                  title: Text('缓存说明'),
                  subtitle: Text(
                    '音频缓存：存储最近播放的音频文件。\n'
                    '字幕缓存：存储最近加载的字幕文件。\n'
                    '列表缓存：存储首页推荐、搜索结果、热门列表、作品详情等数据，'
                    '开启侧边栏的「使用本地缓存加载列表」后，可在网络不稳定时离线浏览。\n'
                    '推荐缓存：内存中的推荐数据，重启应用后自动清除。\n\n'
                    '上限规则：\n'
                    '• 正数 = 上限（MB 或 条目数）\n'
                    '• 0 = 禁用该缓存\n'
                    '• -1 = 无上限，不自动清理',
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

/// 单个缓存类型的展示组件
class _CacheSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final int currentSize;
  final int limitMb;
  final String sizeFormatted;
  final String limitFormatted;
  final VoidCallback onClear;
  final VoidCallback onEditLimit;

  const _CacheSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.currentSize,
    required this.limitMb,
    required this.sizeFormatted,
    required this.limitFormatted,
    required this.onClear,
    required this.onEditLimit,
  });

  double get _progress {
    if (limitMb <= 0) return 0; // 禁用或无上限时进度为 0
    final maxBytes = limitMb * 1024 * 1024;
    if (maxBytes == 0) return 0;
    return (currentSize / maxBytes).clamp(0.0, 1.0);
  }

  Color _progressColor(double progress) {
    if (progress >= 0.9) return Colors.red;
    if (progress >= 0.7) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 进度条
              if (limitMb > 0) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor:
                        AlwaysStoppedAnimation(_progressColor(progress)),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Text(
                '$sizeFormatted / $limitFormatted',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: onClear, child: const Text('清理')),
              TextButton(onPressed: onEditLimit, child: const Text('上限')),
            ],
          ),
        ),
        const Divider(indent: 72),
      ],
    );
  }
}