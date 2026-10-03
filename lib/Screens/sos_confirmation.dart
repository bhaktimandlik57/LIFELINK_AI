import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SOSConfirmationScreen extends StatefulWidget {
  final String emergencyType;

  const SOSConfirmationScreen({
    super.key,
    required this.emergencyType,
  });

  @override
  State<SOSConfirmationScreen> createState() =>
      _SOSConfirmationScreenState();
}

class _SOSConfirmationScreenState extends State<SOSConfirmationScreen> {
  bool isGettingLocation = false;

  String? voicePath;
  bool isVoiceAttached = false;

  @override
  void initState() {
    super.initState();
    loadVoiceMessage();
  }

  Future<void> loadVoiceMessage() async {
    final prefs = await SharedPreferences.getInstance();

    final savedPath = prefs.getString('latest_voice_path');

    if (!mounted) return;

    if (savedPath != null &&
        savedPath.isNotEmpty &&
        File(savedPath).existsSync()) {
      setState(() {
        voicePath = savedPath;
        isVoiceAttached = true;
      });
    } else {
      setState(() {
        voicePath = null;
        isVoiceAttached = false;
      });
    }
  }

  Future<void> sendSOS() async {
    setState(() {
      isGettingLocation = true;
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;

      setState(() {
        isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please turn ON your phone location/GPS.'),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;

      setState(() {
        isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for SOS.'),
        ),
      );
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final sosId =
          'SOS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // IMPORTANT:
      // This packet now contains the actual emergency type
      // selected by the user on the Home Screen.
      final sosData = {
        'sosId': sosId,

        // Actual selected emergency type
        'type': widget.emergencyType,

        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'RELAY_PENDING',
        'network': 'Waiting for network',

        // Actual voice recording path
        'voicePath': voicePath,

        // Actual voice attachment status
        'voiceAttached': isVoiceAttached,
      };

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'latest_sos',
        jsonEncode(sosData),
      );

      if (!mounted) return;

      setState(() {
        isGettingLocation = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SOSSentScreen(
            latitude: position.latitude,
            longitude: position.longitude,
            voiceAttached: isVoiceAttached,
            emergencyType: widget.emergencyType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your current location.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Colors.red,
                size: 70,
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Are you in an emergency?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Press confirm only if you need immediate emergency assistance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 22),

            // SHOW SELECTED EMERGENCY TYPE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emergency,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Emergency Type:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.emergencyType,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // VOICE ATTACHMENT STATUS
            if (isVoiceAttached)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.mic,
                      color: Colors.green,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Voice emergency message attached',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                  ],
                ),
              ),

            if (!isVoiceAttached)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.mic_off,
                      color: Colors.grey,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No voice message attached',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: isGettingLocation ? null : sendSOS,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isGettingLocation
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Getting Location...',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
                    : const Text(
                  'YES, SEND SOS',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton(
                onPressed: isGettingLocation
                    ? null
                    : () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(
                    color: Colors.grey,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'NO, GO BACK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SOSSentScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool voiceAttached;
  final String emergencyType;

  const SOSSentScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.voiceAttached,
    required this.emergencyType,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 80,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'SOS Request Created',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Your emergency request has been stored and is ready to be relayed to the rescue network.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 35),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // EMERGENCY TYPE
                    Row(
                      children: [
                        const Icon(
                          Icons.emergency,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Emergency Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            emergencyType,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    const Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          color: Colors.red,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Location',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text(
                          'Captured',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        const Text(
                          'Latitude:',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          latitude.toStringAsFixed(6),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const Text(
                          'Longitude:',
                          style: TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          longitude.toStringAsFixed(6),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    const Row(
                      children: [
                        Icon(
                          Icons.wifi_off,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Network',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        Text('Relay Pending'),
                      ],
                    ),

                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Icon(
                          voiceAttached
                              ? Icons.mic
                              : Icons.mic_off,
                          color: voiceAttached
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Voice Message',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          voiceAttached
                              ? 'Attached'
                              : 'Not Attached',
                          style: TextStyle(
                            color: voiceAttached
                                ? Colors.green
                                : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(
                      context,
                          (route) => route.isFirst,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'RETURN TO HOME',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
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