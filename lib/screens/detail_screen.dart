import 'package:asmrapp/widgets/mini_player/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/data/models/works/work.dart';
import 'package:asmrapp/widgets/detail/work_cover.dart';
import 'package:asmrapp/widgets/detail/work_info.dart';
import 'package:asmrapp/widgets/detail/work_files_list.dart';
import 'package:asmrapp/widgets/detail/work_files_skeleton.dart';
import 'package:asmrapp/presentation/viewmodels/detail_viewmodel.dart';
import 'package:asmrapp/widgets/detail/work_action_buttons.dart';
import 'package:asmrapp/screens/similar_works_screen.dart';
import 'package:asmrapp/data/repositories/history_repository.dart';

class DetailScreen extends StatefulWidget {
  final Work work;
  final bool fromPlayer;

  const DetailScreen({
    super.key,
    required this.work,
    this.fromPlayer = false,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _historyRecorded = false;

  @override
  void initState() {
    super.initState();
    _recordHistory();
  }

  /// 记录浏览历史（仅首次进入时记录一次）
  void _recordHistory() {
    if (_historyRecorded) return;
    _historyRecorded = true;

    try {
      GetIt.I<HistoryRepository>().recordView(widget.work);
    } catch (e) {
      // 静默失败，不影响主流程
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DetailViewModel(
        work: widget.work,
      )..loadFiles(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.work.sourceId ?? ''),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: MiniPlayer.height),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkCover(
                imageUrl: widget.work.mainCoverUrl ?? '',
                workId: widget.work.id ?? 0,
                sourceId: widget.work.sourceId ?? '',
                releaseDate: widget.work.release,
                heroTag: 'work-cover-${widget.work.id}',
              ),
              WorkInfo(work: widget.work),
              Consumer<DetailViewModel>(
                builder: (context, viewModel, _) => WorkActionButtons(
                  hasRecommendations: viewModel.hasRecommendations,
                  checkingRecommendations: viewModel.checkingRecommendations,
                  onRecommendationsTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            SimilarWorksScreen(work: widget.work),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          const begin = Offset(1.0, 0.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOut;
                          var tween = Tween(begin: begin, end: end).chain(
                            CurveTween(curve: curve),
                          );
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  onFavoriteTap: () => viewModel.showPlaylistsDialog(context),
                  loadingFavorite: viewModel.loadingFavorite,
                  onMarkTap: () => viewModel.showMarkDialog(context),
                  currentMarkStatus: viewModel.currentMarkStatus,
                  loadingMark: viewModel.loadingMark,
                ),
              ),
              Consumer<DetailViewModel>(
                builder: (context, viewModel, _) {
                  if (viewModel.isLoading) {
                    return const WorkFilesSkeleton();
                  }

                  if (viewModel.error != null) {
                    return Center(
                      child: Text(
                        viewModel.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }

                  if (viewModel.files != null) {
                    return WorkFilesList(
                      files: viewModel.files!,
                      onFileTap: (file) async {
                        try {
                          await viewModel.playFile(file, context);
                          // 播放文件时更新历史记录中的音频信息
                          _updateHistoryOnPlay(viewModel, file);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('播放失败: $e')),
                            );
                          }
                        }
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
        bottomSheet: const MiniPlayer(),
      ),
    );
  }

  /// 播放音频时更新历史记录
  void _updateHistoryOnPlay(DetailViewModel viewModel, dynamic file) {
    try {
      final files = viewModel.files;
      if (files == null) return;

      // 查找当前文件在列表中的索引
      int? audioIndex;
      final allFiles = [
        ...?files.children,
        if (files.folder != null) ...files.folder!.children ?? [],
      ];

      for (int i = 0; i < allFiles.length; i++) {
        if (allFiles[i].id == file.id) {
          audioIndex = i;
          break;
        }
      }

      GetIt.I<HistoryRepository>().recordView(
        widget.work,
        audioName: file.title ?? file.name,
        audioIndex: audioIndex,
        progressSeconds: 0,
      );
    } catch (e) {
      // 静默失败
    }
  }
}