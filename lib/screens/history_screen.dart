import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:asmrapp/data/models/history/history_record.dart';
import 'package:asmrapp/presentation/viewmodels/history_viewmodel.dart';
import 'package:asmrapp/screens/detail_screen.dart';
import 'package:asmrapp/data/models/works/work.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
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

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<HistoryViewModel>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '搜索标题、RJ号或文件名…',
                  hintStyle: TextStyle(
				  color: theme.colorScheme.onSurfaceVariant,
				),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  context.read<HistoryViewModel>().search(value.trim());
                },
              )
            : const Text('历史记录'),
        actions: [
          // 搜索按钮
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  context.read<HistoryViewModel>().clearSearch();
                }
              });
            },
          ),
          // 清空按钮
          Consumer<HistoryViewModel>(
            builder: (context, vm, _) {
              if (vm.totalCount == 0) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: '清空全部记录',
                onPressed: () => _confirmClearAll(context),
              );
            },
          ),
        ],
      ),
      body: Consumer<HistoryViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading && vm.records.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!vm.isLoading && vm.records.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 64,
                      color: theme.colorScheme.onSurface.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text(
                    vm.searchQuery.isNotEmpty ? '没有匹配的记录' : '暂无历史记录',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: vm.records.length + (vm.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == vm.records.length) {
                // 加载更多指示器
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              return _HistoryListTile(
                record: vm.records[index],
                onDelete: () => vm.removeRecord(vm.records[index].workId),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史记录'),
        content: const Text('确定要删除全部历史记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<HistoryViewModel>().clearAll();
    }
  }
}

/// 单条历史记录 Widget
class _HistoryListTile extends StatelessWidget {
  final HistoryRecord record;
  final VoidCallback onDelete;

  const _HistoryListTile({
    required this.record,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(record.workId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // 由 ViewModel 处理实际删除
      },
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: record.mainCoverUrl.isNotEmpty
              ? Image.network(
                  record.mainCoverUrl,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholderIcon(theme),
                )
              : _placeholderIcon(theme),
        ),
        title: Text(
          record.title.isNotEmpty ? record.title : record.sourceId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.sourceId.isNotEmpty)
              Text(
                record.sourceId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withAlpha(160),
                ),
              ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.music_note,
                    size: 14, color: theme.colorScheme.onSurface.withAlpha(130)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.lastPlayedFileName.isNotEmpty
                        ? record.lastPlayedFileName
                        : '未知文件',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(130),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(record.lastPlayedTime),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
        onTap: () {
          // 构造一个简化的 Work 对象用于跳转详情页
          final work = Work(
            id: record.workId,
            sourceId: record.sourceId,
            mainCoverUrl: record.mainCoverUrl,
            title: record.title,
          );
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DetailScreen(work: work),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholderIcon(ThemeData theme) {
    return Container(
      width: 52,
      height: 52,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, color: theme.colorScheme.onSurface.withAlpha(120)),
    );
  }

	String _formatTime(DateTime time) {
	  final now = DateTime.now();
	  final today = DateTime(now.year, now.month, now.day);
	  final yesterday = today.subtract(const Duration(days: 1));
	  final timeDate = DateTime(time.year, time.month, time.day);
	  final hourMinute =
		  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

	  if (timeDate == today) {
		return '今天 $hourMinute';
	  } else if (timeDate == yesterday) {
		return '昨天 $hourMinute';
	  } else if (time.year == now.year) {
		return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} $hourMinute';
	  } else {
		return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} $hourMinute';
	  }
	}
}