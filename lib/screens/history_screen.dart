import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:asmrapp/common/constants/strings.dart';
import 'package:asmrapp/data/models/history/history_record.dart';
import 'package:asmrapp/data/models/works/work.dart';
import 'package:asmrapp/presentation/viewmodels/history_viewmodel.dart';
import 'package:asmrapp/screens/detail_screen.dart';
import 'package:asmrapp/widgets/mini_player/mini_player.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    // 初始加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryViewModel>().loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 触底加载更多
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<HistoryViewModel>().loadMore();
    }
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
      if (!_showSearch) {
        _searchController.clear();
        context.read<HistoryViewModel>().clearSearch();
      }
    });
  }

  void _onSearchChanged(String value) {
    context.read<HistoryViewModel>().search(value);
  }

  Future<void> _onDeleteRecord(int workId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Strings.delete),
        content: const Text('确定要删除这条历史记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Strings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<HistoryViewModel>().deleteRecord(workId);
    }
  }

  Future<void> _onClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(Strings.clearAllHistory),
        content: const Text(Strings.deleteHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<HistoryViewModel>().clearAll();
    }
  }

  void _onTapRecord(HistoryRecord record) {
    final work = context.read<HistoryViewModel>().reconstructWork(record);
    if (work == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开该作品详情')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetailScreen(work: work),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HistoryViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: Strings.historySearchHint,
                    hintStyle: TextStyle(color: Colors.white54),
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearchChanged,
                )
              : const Text(Strings.history),
          actions: [
            // 搜索按钮
            IconButton(
              icon: Icon(_showSearch ? Icons.close : Icons.search),
              onPressed: _toggleSearch,
            ),
            // 清空按钮
            Consumer<HistoryViewModel>(
              builder: (context, vm, _) {
                if (vm.totalCount == 0) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: Strings.clearAllHistory,
                  onPressed: _onClearAll,
                );
              },
            ),
          ],
        ),
        body: Consumer<HistoryViewModel>(
          builder: (context, viewModel, _) {
            // 初始加载中
            if (viewModel.isLoading && viewModel.displayedRecords.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            // 空状态
            if (!viewModel.isLoading && viewModel.displayedRecords.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.isSearching ? '未找到匹配记录' : Strings.historyEmpty,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: MiniPlayer.height),
                    itemCount: viewModel.displayedRecords.length +
                        (viewModel.hasMore && !viewModel.isSearching ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 加载更多指示器
                      if (index == viewModel.displayedRecords.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final record = viewModel.displayedRecords[index];
                      return _HistoryListTile(
                        record: record,
                        onTap: () => _onTapRecord(record),
                        onDelete: () => _onDeleteRecord(record.workId),
                      );
                    },
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

/// 单条历史记录瓦片
class _HistoryListTile extends StatelessWidget {
  final HistoryRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _HistoryListTile({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  /// 从 workJson 中安全提取字段
  Map<String, dynamic>? get _workMap {
    try {
      return record.workJson.isNotEmpty
          ? (record.workJson as dynamic) is Map
              ? record.workJson as Map<String, dynamic>
              : null
          : null;
    } catch (_) {
      return null;
    }
  }

  String get _title {
    try {
      final map = _workMap;
      return map?['title']?.toString() ??
          map?['sourceId']?.toString() ??
          '未知作品';
    } catch (_) {
      return '未知作品';
    }
  }

  String? get _coverUrl {
    try {
      return _workMap?['mainCoverUrl']?.toString();
    } catch (_) {
      return null;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    // 超过一周显示具体日期
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[];

    if (record.lastPlayedAudioName != null &&
        record.lastPlayedAudioName!.isNotEmpty) {
      subtitleParts.add(record.lastPlayedAudioName!);
      if (record.lastPlayedProgressInSeconds > 0) {
        subtitleParts.add(_formatDuration(record.lastPlayedProgressInSeconds));
      }
    }

    return Dismissible(
      key: Key('history_${record.workId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // 手动处理删除，不由 Dismissible 移除
      },
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 48,
            height: 48,
            child: _coverUrl != null
                ? CachedNetworkImage(
                    imageUrl: _coverUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Icon(Icons.music_note, size: 24),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceVariant,
                      child: const Icon(Icons.music_note, size: 24),
                    ),
                  )
                : Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: const Icon(Icons.music_note, size: 24),
                  ),
          ),
        ),
        title: Text(
          _title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitleParts.isNotEmpty)
              Text(
                subtitleParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              _formatTime(record.lastPlayedTime),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(179),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(
            Icons.close,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: onDelete,
        ),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}