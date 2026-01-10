import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/activity_log.dart';

class LogRepository {
  static const String _kLogKey = 'wordrop_activity_logs';
  static const int _kMaxLogs = 100; // Limit to last 100 events

  Future<List<ActivityLog>> getLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> logsJson = prefs.getStringList(_kLogKey) ?? [];

    return logsJson.map((e) => ActivityLog.fromJson(jsonDecode(e))).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
  }

  Future<void> addLog(ActivityLog log) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> logsJson = prefs.getStringList(_kLogKey) ?? [];

    // Add new log
    logsJson.add(jsonEncode(log.toJson()));

    // Trim if needed (Keep newest)
    if (logsJson.length > _kMaxLogs) {
      logsJson = logsJson.sublist(logsJson.length - _kMaxLogs);
    }

    await prefs.setStringList(_kLogKey, logsJson);
  }

  Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLogKey);
  }

  Future<void> logError(String message, [StackTrace? stackTrace]) async {
    final log = ActivityLog(
      timestamp: DateTime.now(),
      triggerLabel: "System Error",
      actionType: "Error",
      success: false,
      details: message,
      level: LogLevel.error,
      stackTrace: stackTrace?.toString(),
    );
    await addLog(log);
  }
}
