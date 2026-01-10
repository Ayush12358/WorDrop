import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'dart:convert';
import 'dart:async';
import '../repositories/trigger_word_repository.dart';
import '../repositories/settings_repository.dart';
import '../services/model_downloader_service.dart';
import '../services/background_service_manager.dart';
import '../models/trigger_config.dart';
import '../models/action_data.dart';
import 'app_selection_screen.dart';

class TriggerScreen extends StatefulWidget {
  const TriggerScreen({super.key});

  @override
  State<TriggerScreen> createState() => _TriggerScreenState();
}

class _TriggerScreenState extends State<TriggerScreen> {
  final _repository = TriggerWordRepository();
  final _settingsRepository = SettingsRepository();
  List<TriggerConfig> _triggers = [];
  bool _perTriggerEnabled = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTriggers();
    _checkSettings();
  }

  void _checkSettings() async {
    final enabled = await _settingsRepository.isPerTriggerSensitivityEnabled();
    if (mounted) setState(() => _perTriggerEnabled = enabled);
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

    // 1. Stop Background Service if running
    if (wasRunning) {
      service.invoke('stopService');

      // Poll for service stop (max 3 seconds)
      int retries = 0;
      while (await service.isRunning() && retries < 30) {
        await Future.delayed(const Duration(milliseconds: 100));
        retries++;
      }

      // If still running after 3s, abort to prevent crash
      if (await service.isRunning()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Could not stop background service. Try again.")),
          );
        }
        return null;
      }
    }

    if (!mounted) return null;

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    VoskFlutterPlugin? vosk;
    SpeechService? speechService;
    StreamController<String>? textController;

    try {
      final modelPath = await ModelDownloaderService().getModelPath();
      if (modelPath == null) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("No voice model found. Download one first.")),
          );
        }
        return null;
      }

      vosk = VoskFlutterPlugin.instance();
      final model = await vosk.createModel(modelPath);
      final recognizer = await vosk.createRecognizer(
        model: model,
        sampleRate: 16000,
      );
      speechService = await vosk.initSpeechService(recognizer);

      if (context.mounted) Navigator.pop(context); // Close loading

      textController = StreamController<String>();
      speechService.onPartial().listen((event) {
        try {
          final decoded = jsonDecode(event);
          final partial = decoded['partial'] as String;
          if (partial.isNotEmpty) {
            textController!.add(partial);
          }
        } catch (_) {}
      });

      await speechService.start();

      if (!context.mounted) return null;
      final capturedText = await showDialog<String>(
        context: context,
        builder: (context) => StreamBuilder<String>(
          stream: textController!.stream,
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

      return capturedText;
    } catch (e) {
      debugPrint("Voice Record Error: $e");
      return null;
    } finally {
      // Cleanup
      try {
        await speechService?.stop();
        speechService?.dispose();
        textController?.close();
      } catch (_) {}

      // Restart Service if it was running
      if (wasRunning) {
        await BackgroundServiceManager().initialize();
        // Give it a moment to boot
        await Future.delayed(const Duration(milliseconds: 500));
        await BackgroundServiceManager().start();
      }
    }
  }

  // --- CRUD Logic ---

  void _addCategory() async {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      await _repository.addTriggerWord(text);

      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke("stopService");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Service stopped to apply changes.")),
          );
        }
      }

      _controller.clear();
      _loadTriggers();
    }
  }

  void _removeCategory(String label) async {
    await _repository.removeConfig(label);

    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke("stopService");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Service stopped to apply changes.")),
        );
      }
    }

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
                      if (_perTriggerEnabled) ...[
                        const Text(
                          "Sensitivity Override",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        DropdownButton<String>(
                          value: config.sensitivity ?? 'default',
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'default',
                              child: Text("Global Default"),
                            ),
                            DropdownMenuItem(
                              value: 'fast',
                              child: Text("Fast (High Sensitivity)"),
                            ),
                            DropdownMenuItem(
                              value: 'strict',
                              child: Text("Strict (High Accuracy)"),
                            ),
                          ],
                          onChanged: (val) async {
                            if (val != null) {
                              final newConfig = config.copyWith(
                                sensitivity: val,
                              );
                              await _repository.addConfig(newConfig);

                              final service = FlutterBackgroundService();
                              if (await service.isRunning()) {
                                service.invoke("stopService");
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            "Service stopped to apply changes.")),
                                  );
                                }
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                _editConfig(
                                  newConfig,
                                ); // Re-open with new value
                              }
                            }
                          },
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text("Allow when Device Locked?"),
                          subtitle: const Text(
                            "If disabled, this trigger will be ignored while the screen is locked.",
                          ),
                          value: config.allowWhenLocked,
                          onChanged: (val) async {
                            final newConfig = config.copyWith(
                              allowWhenLocked: val,
                            );
                            await _repository.addConfig(newConfig);

                            final service = FlutterBackgroundService();
                            if (await service.isRunning()) {
                              service.invoke("stopService");
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Service stopped to apply changes.")),
                                );
                              }
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              _editConfig(newConfig);
                            }
                          },
                        ),
                        const Divider(),
                      ],
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

                    final service = FlutterBackgroundService();
                    if (await service.isRunning()) {
                      service.invoke("stopService");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("Service stopped to apply changes.")),
                        );
                      }
                    }

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
                } else if (type == ActionType.webhook) {
                  _showWebhookDialog(context, onAdd);
                } else if (type == ActionType.audioRecord) {
                  onAdd(ActionInstance.create(ActionType.audioRecord));
                } else if (type == ActionType.privacyWipe) {
                  onAdd(ActionInstance.create(ActionType.privacyWipe));
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

  void _showSmsDialog(BuildContext context, Function(ActionInstance) onAdd) {
    final phoneController = TextEditingController();
    final messageController = TextEditingController(
      text: "Help! I triggered my emergency SOS.",
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Configure SOS SMS"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  hintText: "+1234567890",
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                  labelText: "Custom Message",
                  prefixIcon: Icon(Icons.message),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              const Text(
                "Note: Standard SMS rates apply. Location will be appended if permission is granted.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                if (phoneController.text.isNotEmpty) {
                  onAdd(
                    ActionInstance.create(ActionType.emergencySms, {
                      'phone': phoneController.text.trim(),
                      'message': messageController.text.trim(),
                    }),
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Add SOS"),
            ),
          ],
        );
      },
    );
  }

  void _showWebhookDialog(
    BuildContext context,
    Function(ActionInstance) onAdd,
  ) {
    String selectedMethod = "GET";
    final urlController = TextEditingController();
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Configure Webhook"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(
                        labelText: "URL",
                        hintText: "https://api.example.com/trigger",
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 10),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Method",
                        prefixIcon: Icon(Icons.http),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedMethod,
                          isExpanded: true,
                          items: ["GET", "POST"]
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedMethod = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyController,
                      decoration: const InputDecoration(
                        labelText: "Body (JSON - Optional)",
                        hintText: '{"key": "value"}',
                        prefixIcon: Icon(Icons.code),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    if (urlController.text.isNotEmpty) {
                      onAdd(
                        ActionInstance.create(ActionType.webhook, {
                          'url': urlController.text.trim(),
                          'method': selectedMethod,
                          'body': bodyController.text.isNotEmpty
                              ? bodyController.text
                              : null,
                        }),
                      );
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text("Add Webhook"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAppSelectionDialog(
    BuildContext context,
    Function(ActionInstance) onAdd,
  ) async {
    // Navigate to new App Selection Screen
    final packageName = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const AppSelectionScreen()),
    );

    if (packageName != null && packageName.isNotEmpty) {
      onAdd(
        ActionInstance.create(ActionType.launchApp, {'package': packageName}),
      );
    }
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
      case ActionType.webhook:
        return Icons.webhook;
      case ActionType.audioRecord:
        return Icons.mic;
      case ActionType.privacyWipe:
        return Icons.cleaning_services; // or security
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Triggers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Column(
        children: [
          // --- Add Input ---
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'New Trigger Group (e.g. "Panic")',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest.withAlpha(
                        77,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _addCategory,
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),

          // --- Trigger List ---
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _triggers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final config = _triggers[index];
                return Dismissible(
                  key: Key(config.label),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    _removeCategory(config.label);
                    return false; // Let the robust function handle reload logic
                  },
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHighest.withAlpha(77),
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colorScheme.outlineVariant.withAlpha(77),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _editConfig(config),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  config.label,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Aliases
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: config.triggers
                                  .take(5)
                                  .map(
                                    (t) => Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withAlpha(
                                          26,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        t,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),

                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 8),

                            // Actions Preview
                            Row(
                              children: [
                                Text(
                                  "${config.actions.length} Actions:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...config.actions.take(5).map(
                                      (a) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 6,
                                        ),
                                        child: Icon(
                                          _getActionIcon(a.type),
                                          size: 16,
                                          color: colorScheme.secondary,
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
