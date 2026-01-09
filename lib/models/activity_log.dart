class ActivityLog {
  final DateTime timestamp;
  final String triggerLabel;
  final String actionType;
  final bool success;
  final String? details;

  ActivityLog({
    required this.timestamp,
    required this.triggerLabel,
    required this.actionType,
    required this.success,
    this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'triggerLabel': triggerLabel,
      'actionType': actionType,
      'success': success,
      'details': details,
    };
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      timestamp: DateTime.parse(json['timestamp']),
      triggerLabel: json['triggerLabel'] ?? 'Unknown',
      actionType: json['actionType'] ?? 'Unknown',
      success: json['success'] ?? false,
      details: json['details'],
    );
  }
}
