import 'dart:convert';

class HistoryRecord {
  final int workId;
  final String sourceId;
  final String mainCoverUrl;
  final String title;
  final String lastPlayedFileName;
  final DateTime lastPlayedTime;
  final int lastProgressSeconds; // 秒

  const HistoryRecord({
    required this.workId,
    required this.sourceId,
    required this.mainCoverUrl,
    required this.title,
    required this.lastPlayedFileName,
    required this.lastPlayedTime,
    this.lastProgressSeconds = 0,
  });

  /// 从 JSON 反序列化
  factory HistoryRecord.fromJson(Map<String, dynamic> json) {
    return HistoryRecord(
      workId: json['workId'] as int,
      sourceId: json['sourceId'] as String? ?? '',
      mainCoverUrl: json['mainCoverUrl'] as String? ?? '',
      title: json['title'] as String? ?? '',
      lastPlayedFileName: json['lastPlayedFileName'] as String? ?? '',
      lastPlayedTime: DateTime.fromMillisecondsSinceEpoch(
        json['lastPlayedTime'] as int? ?? 0,
      ),
      lastProgressSeconds: json['lastProgressSeconds'] as int? ?? 0,
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'workId': workId,
      'sourceId': sourceId,
      'mainCoverUrl': mainCoverUrl,
      'title': title,
      'lastPlayedFileName': lastPlayedFileName,
      'lastPlayedTime': lastPlayedTime.millisecondsSinceEpoch,
      'lastProgressSeconds': lastProgressSeconds,
    };
  }

  /// 用于搜索匹配（标题、sourceId、文件名）
  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final lower = query.toLowerCase();
    return title.toLowerCase().contains(lower) ||
        sourceId.toLowerCase().contains(lower) ||
        lastPlayedFileName.toLowerCase().contains(lower);
  }

  /// 更新时间与进度，返回新实例
  HistoryRecord updatePlayInfo({
    required DateTime time,
    int progressSeconds = 0,
    String? fileName,
  }) {
    return HistoryRecord(
      workId: workId,
      sourceId: sourceId,
      mainCoverUrl: mainCoverUrl,
      title: title,
      lastPlayedFileName: fileName ?? lastPlayedFileName,
      lastPlayedTime: time,
      lastProgressSeconds: progressSeconds,
    );
  }

  @override
  String toString() =>
      'HistoryRecord(workId: $workId, title: $title, file: $lastPlayedFileName)';
}