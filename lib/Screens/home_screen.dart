import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

import 'sos_confirmation.dart';
import 'report_disaster.dart';
import 'emergency_instructions.dart';
import 'active_report.dart';
import 'lifelink_network.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // =========================
  // EMERGENCY TYPE
  // =========================

  String? selectedEmergencyType;

  final List<String> emergencyTypes = [
    'Medical',
    'Accident',
    'Fire',
    'Crime',
    'Other',
  ];

  // =========================
  // FLASHLIGHT
  // =========================

  bool isFlashlightOn = false;

  // =========================
  // VOICE RECORDING
  // =========================

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

  // =========================
  // FLASHLIGHT
  // =========================

  Future<void> toggleFlashlight() async {
    try {
      if (isFlashlightOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }

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

  // =========================
  // START VOICE RECORDING
  // =========================

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

      recordingTimer = Timer.periodic(
        const Duration(seconds: 1),
            (_) {
          if (!mounted) return;

          setState(() {
            recordingDuration += const Duration(seconds: 1);
          });
        },
      );

      setState(() {
        isRecording = true;
        recordingDuration = Duration.zero;
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

  // =========================
  // STOP VOICE RECORDING
  // =========================

  Future<void> stopVoiceRecording() async {
    try {
      recordingTimer?.cancel();

      final path = await _audioRecorder.stop();

      setState(() {
        isRecording = false;
        voicePath = path;
      });

      if (path != null && path.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString(
          'latest_voice_path',
          path,
        );

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

  // =========================
  // VOICE BUTTON
  // =========================

  Future<void> handleVoiceButton() async {
    if (isRecording) {
      await stopVoiceRecording();
    } else {
      await startVoiceRecording();
    }
  }

  // =========================
  // SEND SOS
  // =========================

  void openSOSConfirmation() {
    if (selectedEmergencyType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an emergency type first.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SOSConfirmationScreen(
          emergencyType: selectedEmergencyType!,
        ),
      ),
    );
  }

  // =========================
  // EMERGENCY ICON
  // =========================

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

      case 'Other':
        return Icons.warning_amber_outlined;

      default:
        return Icons.warning_amber_outlined;
    }
  }

  // =========================
  // QUICK ACTION
  // =========================

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
                color: active
                    ? Colors.red
                    : const Color(0xFF1976D2),
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

  // =========================
  // BUILD
  // =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'LIFELINK AI',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // =========================
              // WELCOME
              // =========================

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

              // =========================
              // EMERGENCY TYPE
              // =========================

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
                hint: const Text(
                  'Select Emergency Type',
                ),
                decoration: InputDecoration(
                  prefixIcon: selectedEmergencyType == null
                      ? const Icon(
                    Icons.warning_amber_outlined,
                  )
                      : Icon(
                    emergencyIcon(
                      selectedEmergencyType!,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.grey.shade300,
                    ),
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
                items: emergencyTypes.map(
                      (type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  },
                ).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedEmergencyType = value;
                  });
                },
              ),

              const SizedBox(height: 24),

              // =========================
              // SOS BUTTON
              // =========================

              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton.icon(
                  onPressed: openSOSConfirmation,
                  icon: const Icon(
                    Icons.sos,
                    size: 30,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'SEND SOS',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // =========================
              // QUICK ACTIONS
              // =========================

              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Row(
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
                    title: isRecording
                        ? 'Stop Voice'
                        : 'Voice Message',
                    active: isRecording,
                    onTap: handleVoiceButton,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (isRecording)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.mic,
                        color: Colors.red,
                      ),
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

              if (voicePath != null && !isRecording)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Voice message attached',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 28),

              // =========================
              // REPORT DISASTER
              // =========================

              const Text(
                'Report a Disaster',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const ReportDisasterScreen(),
                    ),
                  );
                },
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
                  child: const Row(
                    children: [
                      Icon(
                        Icons.report_problem_outlined,
                        color: Colors.orange,
                        size: 30,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Report a disaster or dangerous situation.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // =========================
              // LIFELINK NETWORK
              // =========================

              const Text(
                'LIFELINK Network',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const LifelinkNetworkScreen(),
                    ),
                  );
                },
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
                  child: const Row(
                    children: [
                      Icon(
                        Icons.hub_outlined,
                        color: Color(0xFF1976D2),
                        size: 30,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Connect with nearby LIFELINK users.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // =========================
              // ACTIVE REPORTS
              // =========================

              const Text(
                'Active Reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const ActiveReportsScreen(),
                    ),
                  );
                },
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
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 30,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'View active emergency and disaster reports.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // =========================
              // EMERGENCY INSTRUCTIONS
              // =========================

              const Text(
                'Emergency Instructions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                      const EmergencyInstructionsScreen(),
                    ),
                  );
                },
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
                  child: const Row(
                    children: [
                      Icon(
                        Icons.menu_book_outlined,
                        color: Colors.green,
                        size: 30,
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Get instructions for different emergency situations.',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}