enum LogLevel { info, warning, error }

class ActivityLog {
  final DateTime timestamp;
  final String triggerLabel;
  final String actionType;
  final bool success;
  final String? details;
  final LogLevel level;
  final String? stackTrace;

  ActivityLog({
    required this.timestamp,
    required this.triggerLabel,
    required this.actionType,
    required this.success,
    this.details,
    this.level = LogLevel.info,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'triggerLabel': triggerLabel,
      'actionType': actionType,
      'success': success,
      'details': details,
      'level': level.toString(),
      'stackTrace': stackTrace,
    };
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      timestamp: DateTime.parse(json['timestamp']),
      triggerLabel: json['triggerLabel'] ?? 'Unknown',
      actionType: json['actionType'] ?? 'Unknown',
      success: json['success'] ?? false,
      details: json['details'],
      level: json['level'] != null
          ? LogLevel.values.firstWhere(
              (e) => e.toString() == json['level'],
              orElse: () => LogLevel.info,
            )
          : LogLevel.info,
      stackTrace: json['stackTrace'],
    );
  }
}
