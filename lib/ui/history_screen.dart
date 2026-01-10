import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/activity_log.dart';
import '../repositories/log_repository.dart';

import 'package:flutter/services.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repository = LogRepository();
  List<ActivityLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await _repository.getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    await _repository.clearLogs();
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Activity History"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Clear History",
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Clear History?"),
                  content: const Text("This action cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _clearLogs();
                      },
                      child: const Text("Clear"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No activity recorded yet."),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color iconColor = Colors.green;
                    IconData iconData = Icons.check_circle;

                    if (log.level == LogLevel.error) {
                      iconColor = Colors.red;
                      iconData = Icons.error;
                    } else if (log.level == LogLevel.warning) {
                      iconColor = Colors.orange;
                      iconData = Icons.warning;
                    }

                    return ListTile(
                      leading: Icon(iconData, color: iconColor),
                      title: Text(log.triggerLabel),
                      subtitle: Text(
                        "${log.actionType} • ${DateFormat('MMM d, h:mm a').format(log.timestamp)}",
                      ),
                      onTap: () {
                        if (log.details != null || log.stackTrace != null) {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(log.triggerLabel),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (log.details != null) ...[
                                      const Text(
                                        "Details:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SelectableText(log.details!),
                                      const SizedBox(height: 10),
                                    ],
                                    if (log.stackTrace != null) ...[
                                      const Text(
                                        "Stack Trace:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        color: Colors.grey[200],
                                        child: SelectableText(
                                          log.stackTrace!,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Close"),
                                ),
                                if (log.stackTrace != null ||
                                    log.details != null)
                                  TextButton(
                                    onPressed: () {
                                      final text =
                                          "${log.details ?? ''}\n\n${log.stackTrace ?? ''}"
                                              .trim();
                                      Clipboard.setData(
                                          ClipboardData(text: text));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                "Error Log copied to clipboard"),
                                          ),
                                        );
                                        Navigator.pop(ctx);
                                      }
                                    },
                                    child: const Text("Copy"),
                                  ),
                              ],
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}
