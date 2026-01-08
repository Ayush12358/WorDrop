import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'dart:convert';
import 'dart:async';
import '../repositories/trigger_word_repository.dart';
import '../services/model_downloader_service.dart';
import '../services/background_service_manager.dart';
import '../models/trigger_config.dart';
import '../models/action_data.dart';

class TriggerScreen extends StatefulWidget {
  const TriggerScreen({super.key});

  @override
  State<TriggerScreen> createState() => _TriggerScreenState();
}

class _TriggerScreenState extends State<TriggerScreen> {
  final _repository = TriggerWordRepository();
  List<TriggerConfig> _triggers = [];
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTriggers();
  }

  void _loadTriggers() async {
    final list = await _repository.getConfigs();
    setState(() {
      _triggers = list;
    });
  }

  // --- Voice Input Logic (Reusable) ---
  Future<String?> _recordVoice(BuildContext context) async {
    final service = FlutterBackgroundService();
    final wasRunning = await service.isRunning();

    if (wasRunning) {
      service.invoke('stopService');
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (!mounted) return null;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    try {
      final modelPath = await ModelDownloaderService().getModelPath();
      if (modelPath == null) {
        if (context.mounted) Navigator.pop(context);
        return null;
      }

      final vosk = VoskFlutterPlugin.instance();
      final model = await vosk.createModel(modelPath);
      final recognizer = await vosk.createRecognizer(
        model: model,
        sampleRate: 16000,
      );
      final speechService = await vosk.initSpeechService(recognizer);

      if (context.mounted) Navigator.pop(context); // Close loading

      final StreamController<String> textController =
          StreamController<String>();
      speechService.onPartial().listen((event) {
        try {
          final decoded = jsonDecode(event);
          final partial = decoded['partial'] as String;
          if (partial.isNotEmpty) {
            textController.add(partial);
          }
        } catch (_) {}
      });

      await speechService.start();

      if (!context.mounted) return null; // Check before dialog
      final capturedText = await showDialog<String>(
        context: context,
        builder: (context) => StreamBuilder<String>(
          stream: textController.stream,
          initialData: "",
          builder: (context, snapshot) {
            final text = snapshot.data ?? "";
            return AlertDialog(
              title: const Text("Listening..."),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, size: 60, color: Colors.redAccent),
                  const SizedBox(height: 20),
                  Text(
                    text.isEmpty ? "..." : text,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: text.isNotEmpty
                      ? () => Navigator.pop(context, text)
                      : null,
                  child: const Text("Use This"),
                ),
              ],
            );
          },
        ),
      );

      await speechService.stop();
      speechService.dispose();
      textController.close();

      return capturedText;
    } catch (e) {
      return null;
    } finally {
      if (wasRunning) {
        await BackgroundServiceManager().initialize();
      }
    }
  }

  // --- CRUD Logic ---

  void _addCategory() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      // Create new config with Label = text, and initial Trigger = text
      await _repository.addTriggerWord(text); // Helper uses defaults
      _controller.clear();
      _loadTriggers();
    }
  }

  void _removeCategory(String label) async {
    await _repository.removeConfig(label);
    _loadTriggers();
  }

  void _editConfig(TriggerConfig config) async {
    String label = config.label;
    List<String> triggers = List.from(config.triggers);
    List<ActionInstance> actions = List.from(config.actions);

    final triggerController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Edit Category"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: "Category Name",
                        ),
                        controller: TextEditingController(text: label),
                        onChanged: (v) => label = v,
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Actions",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              _showAddActionDialog(context, (newAction) {
                                setState(() {
                                  actions.add(newAction);
                                });
                              });
                            },
                          ),
                        ],
                      ),
                      // Action List
                      if (actions.isEmpty)
                        const Text(
                          "No actions set.",
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ...actions.map(
                        (a) => ListTile(
                          dense: true,
                          leading: Icon(_getActionIcon(a.type)),
                          title: Text(_getActionName(a.type)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() => actions.remove(a)),
                          ),
                        ),
                      ),

                      const Divider(),
                      const Text(
                        "Trigger Phrases (Aliases)",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: triggerController,
                              decoration: const InputDecoration(
                                hintText: "Add alias",
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.mic),
                            onPressed: () async {
                              final text = await _recordVoice(context);
                              if (text != null && text.isNotEmpty) {
                                setState(() {
                                  if (!triggers.contains(text)) {
                                    triggers.add(text);
                                  }
                                });
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () {
                              if (triggerController.text.isNotEmpty) {
                                setState(() {
                                  triggers.add(triggerController.text.trim());
                                  triggerController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8.0,
                        children: triggers
                            .map(
                              (t) => Chip(
                                label: Text(t),
                                onDeleted: () =>
                                    setState(() => triggers.remove(t)),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () async {
                    final newConfig = config.copyWith(
                      label: label,
                      triggers: triggers,
                      actions: actions,
                    );
                    await _repository.addConfig(newConfig);
                    if (context.mounted) {
                      Navigator.pop(context);
                      _loadTriggers();
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddActionDialog(
    BuildContext context,
    Function(ActionInstance) onAdd,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return SimpleDialog(
          children: ActionType.values.map((type) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(ctx);
                if (type == ActionType.launchApp) {
                  _showAppSelectionDialog(context, onAdd);
                } else if (type == ActionType.emergencySms) {
                  _showSmsDialog(context, onAdd);
                } else {
                  onAdd(ActionInstance.create(type));
                }
              },
              child: Row(
                children: [
                  Icon(_getActionIcon(type), size: 20),
                  const SizedBox(width: 10),
                  Text(_getActionName(type)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showAppSelectionDialog(
    BuildContext context,
    Function(ActionInstance) onAdd,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Enter App Package Name"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("e.g., com.spotify.music"),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: "Package Name"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onAdd(
                    ActionInstance.create(ActionType.launchApp, {
                      'package': controller.text.trim(),
                    }),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  IconData _getActionIcon(ActionType type) {
    switch (type) {
      case ActionType.pauseMedia:
        return Icons.pause;
      case ActionType.vibrate:
        return Icons.vibration;
      case ActionType.flash:
        return Icons.flashlight_on;
      case ActionType.muteAll:
        return Icons.volume_off;
      case ActionType.clearClipboard:
        return Icons.content_paste_off;
      case ActionType.lockDevice:
        return Icons.lock;
      case ActionType.loudSiren:
        return Icons.notifications_active;
      case ActionType.emergencySms:
        return Icons.sms_failed;
      case ActionType.fakeCall:
        return Icons.call;
      case ActionType.launchApp:
        return Icons.apps;
      default:
        return Icons.help;
    }
  }

  String _getActionName(ActionType type) {
    // Convert camelCase to Space Separated
    return type.name
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (Match m) => "${m[1]} ${m[2]}",
        )
        .replaceFirstMapped(
          RegExp(r'([a-z])'),
          (Match m) => m[1]!.toUpperCase(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trigger Categories')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'New Category Name (e.g. "Ayush")',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addCategory,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _triggers.length,
              itemBuilder: (context, index) {
                final config = _triggers[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      config.label.isNotEmpty
                          ? config.label[0].toUpperCase()
                          : "?",
                    ),
                  ),
                  title: Text(
                    config.label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${config.triggers.length} aliases • ${config.actions.length} Actions",
                  ),
                  onTap: () => _editConfig(config),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _removeCategory(config.label),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
