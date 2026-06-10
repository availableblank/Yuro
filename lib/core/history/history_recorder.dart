import 'dart:async';
import 'package:asmrapp/core/audio/events/playback_event.dart';
import 'package:asmrapp/core/audio/events/playback_event_hub.dart';
import 'package:asmrapp/core/audio/models/playback_context.dart';
import 'package:asmrapp/data/models/history/history_record.dart';
import 'package:asmrapp/data/repositories/history_repository.dart';
import 'package:asmrapp/utils/logger.dart';

/// 独立的历史记录器，监听播放事件流，自动记录播放历史。
///
/// 写入策略：
/// - 切换作品时：立即记录上一条 + 创建新记录
/// - 开始播放时：立即记录 + 启动每 2 秒的进度更新定时器
/// - 暂停时：停止定时器 + 记录最终进度
/// - 播放中每 2 秒：更新当前进度
class HistoryRecorder {
  final PlaybackEventHub _eventHub;
  final HistoryRepository _repository;

  StreamSubscription? _contextSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _progressSub;
  Timer? _progressTimer;

  PlaybackContext? _currentContext;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;

  HistoryRecorder({
    required PlaybackEventHub eventHub,
    required HistoryRepository repository,
  })  : _eventHub = eventHub,
        _repository = repository;

  /// 启动监听（应在所有服务注册完毕后调用一次）
  void start() {
    _contextSub = _eventHub.contextChange.listen(_onContextChanged);
    _stateSub = _eventHub.playbackState.listen(_onPlaybackStateChanged);
    _progressSub = _eventHub.playbackProgress.listen(_onProgressChanged);
    AppLogger.info('HistoryRecorder 已启动');
  }

  // ── 事件处理 ──

  void _onContextChanged(PlaybackContextEvent event) {
    // 切换作品前保存上一个作品的最终进度
    if (_currentContext != null) {
      _writeHistory();
    }
    _currentContext = event.context;
    _currentPosition = Duration.zero;
    _isPlaying = false;
    // 立即为新作品创建历史记录
    _writeHistory();
  }

  void _onPlaybackStateChanged(PlaybackStateEvent event) {
    final wasPlaying = _isPlaying;
    _isPlaying = event.state.playing;
    _currentPosition = event.position;

    if (_isPlaying && !wasPlaying) {
      _startProgressTimer();
      _writeHistory();
    } else if (!_isPlaying && wasPlaying) {
      _stopProgressTimer();
      _writeHistory();
    }
  }

  void _onProgressChanged(PlaybackProgressEvent event) {
    _currentPosition = event.position;
  }

  // ── 定时器 ──

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isPlaying) {
        _writeHistory();
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  // ── 写入 ──

  void _writeHistory() {
    final context = _currentContext;
    if (context == null) return;

    try {
      final work = context.work;
      final file = context.currentFile;

      final record = HistoryRecord(
        workId: work.id ?? 0,
        sourceId: work.sourceId ?? '',
        mainCoverUrl: work.mainCoverUrl ?? '',
        title: work.title ?? '',
        lastPlayedFileName: file.title ?? file.workTitle ?? '',
        lastPlayedTime: DateTime.now(),
        lastProgressSeconds: _currentPosition.inSeconds,
      );

      _repository.addOrUpdate(record);
    } catch (e) {
      AppLogger.error('HistoryRecorder 写入失败', e);
    }
  }

  // ── 释放 ──

  void dispose() {
    _contextSub?.cancel();
    _stateSub?.cancel();
    _progressSub?.cancel();
    _stopProgressTimer();
  }
}