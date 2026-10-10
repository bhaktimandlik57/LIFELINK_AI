
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

import 'live_location.dart';
import 'emergency_contacts.dart';
import 'sos_confirmation.dart';
import 'report_disaster.dart';
import 'emergency_instructions.dart';
import 'active_report.dart';
import 'lifelink_network.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // EMERGENCY TYPE
  String? selectedEmergencyType;

  final List<String> emergencyTypes = [
    'FLOOD',
    'CYCLONE',
    'EARTHQUAKE',
    'LANDSLIDE',
    'Other',
  ];

  // FLASHLIGHT
  bool isFlashlightOn = false;

  // VOICE RECORDING
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool isRecording = false;
  String? voicePath;

  Timer? recordingTimer;
  Duration recordingDuration = Duration.zero;

  @override
  void dispose() {
    recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  // FLASHLIGHT
  Future<void> toggleFlashlight() async {
    try {
      if (isFlashlightOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }

      if (!mounted) return;

      setState(() {
        isFlashlightOn = !isFlashlightOn;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to control flashlight.'),
        ),
      );
    }
  }

  // START VOICE RECORDING
  Future<void> startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();

      if (!hasPermission) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required.'),
          ),
        );
        return;
      }

      final directory = await getApplicationDocumentsDirectory();

      final path =
          '${directory.path}/lifelink_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      recordingTimer?.cancel();
      recordingDuration = Duration.zero;

      recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
            (_) {
          if (!mounted) return;

          setState(() {
            recordingDuration += const Duration(seconds: 1);
          });
        },
      );

      if (!mounted) return;

      setState(() {
        isRecording = true;
        voicePath = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start recording: $e'),
        ),
      );
    }
  }

  // STOP VOICE RECORDING
  Future<void> stopVoiceRecording() async {
    try {
      recordingTimer?.cancel();

      final path = await _audioRecorder.stop();

      if (!mounted) return;

      setState(() {
        isRecording = false;
        voicePath = path;
      });

      if (path != null && path.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('latest_voice_path', path);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice message attached successfully.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not stop recording: $e'),
        ),
      );
    }
  }

  // VOICE BUTTON
  Future<void> handleVoiceButton() async {
    if (isRecording) {
      await stopVoiceRecording();
    } else {
      await startVoiceRecording();
    }
  }

  // SEND SOS
  Future<void> openSOSConfirmation() async {
    if (selectedEmergencyType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an emergency type first.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // Remove any previous voice attachment if no new one was recorded.
    if (voicePath == null || voicePath!.isEmpty) {
      await prefs.remove('latest_voice_path');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SOSConfirmationScreen(
          emergencyType: selectedEmergencyType!,
        ),
      ),
    );
  }

  // EMERGENCY ICON
  IconData emergencyIcon(String type) {
    switch (type) {
      case 'Medical':
        return Icons.medical_services_outlined;
      case 'Accident':
        return Icons.car_crash_outlined;
      case 'Fire':
        return Icons.local_fire_department_outlined;
      case 'Crime':
        return Icons.local_police_outlined;
      default:
        return Icons.warning_amber_outlined;
    }
  }

  // QUICK ACTION CARD
  Widget quickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 30,
                color: active ? Colors.red : const Color(0xFF1976D2),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FULL-WIDTH NAVIGATION CARD
  Widget navigationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('LIFELINK AI'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // WELCOME
              const Text(
                'Emergency Assistance',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the emergency type and send an SOS when needed.',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 24),

              // EMERGENCY TYPE
              const Text(
                'Emergency Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: selectedEmergencyType,
                hint: const Text('Select Emergency Type'),
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: selectedEmergencyType == null
                      ? const Icon(Icons.warning_amber_outlined)
                      : Icon(emergencyIcon(selectedEmergencyType!)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1976D2),
                      width: 2,
                    ),
                  ),
                ),
                items: emergencyTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedEmergencyType = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              // SOS BUTTON
              Center(
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: ElevatedButton(
                    onPressed: openSOSConfirmation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 4,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      'SEND SOS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // QUICK ACTIONS
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  quickAction(
                    icon: isFlashlightOn
                        ? Icons.flashlight_on
                        : Icons.flashlight_off,
                    title: isFlashlightOn
                        ? 'Turn Off Flashlight'
                        : 'Flashlight',
                    active: isFlashlightOn,
                    onTap: toggleFlashlight,
                  ),
                  const SizedBox(width: 12),
                  quickAction(
                    icon: isRecording
                        ? Icons.stop_circle_outlined
                        : Icons.mic_none_outlined,
                    title: isRecording ? 'Stop Voice' : 'Voice Message',
                    active: isRecording,
                    onTap: handleVoiceButton,
                  ),
                ],
              ),

              // VOICE RECORDING STATUS
              if (isRecording) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.red),
                      const SizedBox(width: 10),
                      Text(
                        'Recording: ${recordingDuration.inSeconds}s',
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (voicePath != null && !isRecording) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Voice message attached',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // EMERGENCY CONTACTS
              const Text(
                'Emergency Contacts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              navigationCard(
                icon: Icons.contacts,
                iconColor: Colors.red,
                title: 'Emergency Contacts',
                subtitle: 'Manage your trusted emergency contacts.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyContactsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // LIVE LOCATION
              const Text(
                'Live Location',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              navigationCard(
                icon: Icons.location_on,
                iconColor: Colors.red,
                title: 'Live Location',
                subtitle: 'View your current GPS location on map.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LiveLocationScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // REPORT A DISASTER
              const Text(
                'Report a Disaster',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              navigationCard(
                icon: Icons.report_problem_outlined,
                iconColor: Colors.orange,
                title: 'Report a Disaster',
                subtitle: 'Report a disaster or dangerous situation.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportDisasterScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // LIFELINK NETWORK
              const Text(
                'LIFELINK Network',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              navigationCard(
                icon: Icons.hub_outlined,
                iconColor: const Color(0xFF1976D2),
                title: 'LIFELINK Network',
                subtitle: 'Connect with nearby LIFELINK users.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LifelinkNetworkScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // ACTIVE REPORTS
              const Text(
                'Active Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              navigationCard(
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.red,
                title: 'Active Reports',
                subtitle: 'View active emergency and disaster reports.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActiveReportsScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // EMERGENCY INSTRUCTIONS
              const Text(
                'Emergency Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              navigationCard(
                icon: Icons.menu_book_outlined,
                iconColor: Colors.green,
                title: 'Emergency Instructions',
                subtitle:
                'Get instructions for different emergency situations.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const EmergencyInstructionsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
