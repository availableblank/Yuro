import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_record.freezed.dart';
part 'history_record.g.dart';

@freezed
class HistoryRecord with _$HistoryRecord {
  const factory HistoryRecord({
    /// 作品 ID
    required int workId,

    /// 作品完整 JSON（用于反序列化为 Work 对象后导航到详情页）
    required String workJson,

    /// 最后播放的音频文件名
    String? lastPlayedAudioName,

    /// 最后播放的音频在文件列表中的索引
    int? lastPlayedAudioIndex,

    /// 最后播放进度（秒）
    @Default(0) int lastPlayedProgressInSeconds,

    /// 最后播放/查看时间
    required DateTime lastPlayedTime,
  }) = _HistoryRecord;

  factory HistoryRecord.fromJson(Map<String, dynamic> json) =>
      _$HistoryRecordFromJson(json);
}