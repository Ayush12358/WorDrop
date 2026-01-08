import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  const FakeCallScreen({super.key, this.callerName = "Unknown"});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  void _startRinging() async {
    // Vibrate
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 1000, 1000], repeat: 1);
    }
    // Play Ringtone
    FlutterRingtonePlayer().playRingtone(looping: true);
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark theme like standard call
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 50),
            Column(
              children: [
                const CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.callerName,
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Mobile",
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
              ],
            ),
            const Spacer(),
            // Decline / Accept Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 80.0, left: 40, right: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "decline",
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: Colors.red,
                        child: const Icon(Icons.call_end),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Decline",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "accept",
                        onPressed: () {
                          // Show "Connected" UI?
                          Navigator.pop(context); // Just close for now
                        },
                        backgroundColor: Colors.green,
                        child: const Icon(Icons.call),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Accept",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
