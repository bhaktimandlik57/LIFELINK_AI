
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// SOS CONFIRMATION SCREEN
// ============================================================

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

class _SOSConfirmationScreenState
extends State<SOSConfirmationScreen> {
bool isGettingLocation = false;

String? voicePath;
bool isVoiceAttached = false;

@override
void initState() {
super.initState();
loadVoiceMessage();
}

// LOAD THE CURRENT VOICE MESSAGE
Future<void> loadVoiceMessage() async {
try {
final prefs = await SharedPreferences.getInstance();
final savedPath = prefs.getString('latest_voice_path');

if (savedPath != null &&
savedPath.isNotEmpty &&
await File(savedPath).exists()) {
if (!mounted) return;

setState(() {
voicePath = savedPath;
isVoiceAttached = true;
});
} else {
await prefs.remove('latest_voice_path');

if (!mounted) return;

setState(() {
voicePath = null;
isVoiceAttached = false;
});
}
} catch (_) {
if (!mounted) return;

setState(() {
voicePath = null;
isVoiceAttached = false;
});
}
}

// SEND SOS
Future<void> sendSOS() async {
if (isGettingLocation) return;

setState(() {
isGettingLocation = true;
});

try {
// CHECK LOCATION SERVICE
final bool serviceEnabled =
await Geolocator.isLocationServiceEnabled();

if (!serviceEnabled) {
_resetSendingState();

if (!mounted) return;
_showMessage('Please turn on location services.');
return;
}

// CHECK LOCATION PERMISSION
LocationPermission permission =
await Geolocator.checkPermission();

if (permission == LocationPermission.denied) {
permission = await Geolocator.requestPermission();
}

if (permission == LocationPermission.denied ||
permission == LocationPermission.deniedForever) {
_resetSendingState();

if (!mounted) return;
_showMessage(
'Location permission is required to send SOS.',
);
return;
}

// GET CURRENT LOCATION
final Position position =
await Geolocator.getCurrentPosition(
locationSettings: const LocationSettings(
accuracy: LocationAccuracy.medium,
),
);

// VERIFY VOICE FILE
String? validVoicePath = voicePath;
bool validVoiceAttached = isVoiceAttached;

if (validVoicePath != null &&
!await File(validVoicePath).exists()) {
validVoicePath = null;
validVoiceAttached = false;
}

// CREATE SOS ID
final String sosId =
'SOS-${DateTime.now().millisecondsSinceEpoch}';

// PREPARE SOS DATA
final Map<String, dynamic> sosData = {
'sosId': sosId,
'type': widget.emergencyType,
'latitude': position.latitude,
'longitude': position.longitude,
'timestamp': DateTime.now().toIso8601String(),
'status': 'RELAY_PENDING',
'network': 'Waiting for network',
'voicePath': validVoicePath,
'voiceAttached': validVoiceAttached,
};

// SAVE SOS LOCALLY
final prefs = await SharedPreferences.getInstance();

await prefs.setString(
'latest_sos',
jsonEncode(sosData),
);

// Clear the saved voice path so an old recording
// is not automatically attached to the next SOS.
await prefs.remove('latest_voice_path');

if (!mounted) return;

setState(() {
isGettingLocation = false;
voicePath = null;
isVoiceAttached = false;
});

// OPEN SOS SENT SCREEN
Navigator.push(
context,
MaterialPageRoute(
builder: (context) => SOSSentScreen(
latitude: position.latitude,
longitude: position.longitude,
voiceAttached: validVoiceAttached,
emergencyType: widget.emergencyType,
),
),
);
} catch (e) {
_resetSendingState();

if (!mounted) return;
_showMessage('Unable to send SOS: $e');
}
}

void _resetSendingState() {
if (!mounted) return;

setState(() {
isGettingLocation = false;
});
}

void _showMessage(String message) {
ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: const Color(0xFFF7F8FA),
appBar: AppBar(
title: const Text(
'Emergency SOS',
style: TextStyle(fontWeight: FontWeight.bold),
),
backgroundColor: Colors.white,
foregroundColor: Colors.black,
elevation: 0,
),
body: SafeArea(
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
children: [
const SizedBox(height: 20),
Container(
width: 80,
height: 80,
decoration: BoxDecoration(
color: Colors.red.withValues(alpha: 0.10),
shape: BoxShape.circle,
),
child: const Icon(
Icons.warning_rounded,
color: Colors.red,
size: 45,
),
),
const SizedBox(height: 24),
const Text(
'Are you in an emergency?',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 25,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
const Text(
'Your emergency alert will be saved '
'for the rescue network.',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.grey,
fontSize: 15,
),
),
const SizedBox(height: 30),
_infoCard(
icon: Icons.emergency,
iconColor: Colors.red,
title: 'Emergency Type',
value: widget.emergencyType,
borderColor: Colors.red,
),
const SizedBox(height: 15),
_infoCard(
icon: isVoiceAttached ? Icons.mic : Icons.mic_off,
iconColor: Colors.blue,
title: 'Voice Message',
value: isVoiceAttached
? 'Voice message attached'
    : 'No voice message attached',
borderColor: Colors.blue,
),
const SizedBox(height: 30),

// SEND SOS BUTTON
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
? const SizedBox(
width: 24,
height: 24,
child: CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2,
),
)
    : const Text(
'YES, SEND SOS',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
),
const SizedBox(height: 12),

// CANCEL BUTTON
SizedBox(
width: double.infinity,
height: 55,
child: OutlinedButton(
onPressed: isGettingLocation
? null
    : () => Navigator.pop(context),
style: OutlinedButton.styleFrom(
foregroundColor: Colors.black87,
side: const BorderSide(color: Colors.grey),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
child: const Text(
'NO, GO BACK',
style: TextStyle(
fontSize: 16,
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

Widget _infoCard({
required IconData icon,
required Color iconColor,
required String title,
required String value,
required Color borderColor,
}) {
return Container(
width: double.infinity,
padding: const EdgeInsets.all(18),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
border: Border.all(
color: borderColor.withValues(alpha: 0.15),
),
),
child: Row(
children: [
Container(
width: 48,
height: 48,
decoration: BoxDecoration(
color: iconColor.withValues(alpha: 0.10),
borderRadius: BorderRadius.circular(12),
),
child: Icon(icon, color: iconColor),
),
const SizedBox(width: 14),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: const TextStyle(
color: Colors.grey,
fontSize: 13,
),
),
const SizedBox(height: 4),
Text(
value,
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
),
),
],
),
),
],
),
);
}
}

// ============================================================
// SOS SENT SCREEN
// ============================================================

class SOSSentScreen extends StatefulWidget {
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
State<SOSSentScreen> createState() => _SOSSentScreenState();
}

class _SOSSentScreenState extends State<SOSSentScreen> {
bool _stopping = false;

// STOP SOS
Future<void> _stopSOS() async {
if (_stopping) return;

setState(() {
_stopping = true;
});

try {
final prefs = await SharedPreferences.getInstance();
final savedSOS = prefs.getString('latest_sos');

if (savedSOS != null) {
try {
final Map<String, dynamic> sosData =
Map<String, dynamic>.from(
jsonDecode(savedSOS) as Map,
);

sosData['status'] = 'STOPPED';

await prefs.setString(
'latest_sos',
jsonEncode(sosData),
);
} catch (_) {
// Keep navigation available if stored data is invalid.
}
}
} catch (_) {
// Allow navigation even if saving fails.
}

if (!mounted) return;

Navigator.pop(context);
}

@override
Widget build(BuildContext context) {
const Color alertColor = Colors.red;

return Scaffold(
backgroundColor: const Color(0xFFF7F8FA),
body: SafeArea(
child: Container(
decoration: BoxDecoration(
border: Border.all(
color: alertColor,
width: 6,
),
),
child: SingleChildScrollView(
padding: const EdgeInsets.all(24),
child: Column(
children: [
const SizedBox(height: 20),
Container(
width: 85,
height: 85,
decoration: BoxDecoration(
color: Colors.green.withValues(alpha: 0.10),
shape: BoxShape.circle,
),
child: const Icon(
Icons.check_circle,
color: Colors.green,
size: 55,
),
),
const SizedBox(height: 24),
const Text(
'SOS Request Created',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 25,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
const Text(
'Your emergency request has been stored '
'and is ready to be relayed to the rescue network.',
textAlign: TextAlign.center,
style: TextStyle(
color: Colors.grey,
fontSize: 15,
height: 1.4,
),
),
const SizedBox(height: 30),
Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.04),
blurRadius: 10,
offset: const Offset(0, 4),
),
],
),
child: Column(
children: [
_infoRow(
'Emergency Type',
widget.emergencyType,
Icons.emergency,
),
const Divider(height: 28),
_infoRow(
'Location',
'Captured',
Icons.location_on,
),
const SizedBox(height: 18),
_infoRow(
'Latitude',
widget.latitude.toStringAsFixed(6),
Icons.my_location,
),
const SizedBox(height: 18),
_infoRow(
'Longitude',
widget.longitude.toStringAsFixed(6),
Icons.my_location,
),
const Divider(height: 28),
_infoRow(
'Network',
'Relay Pending',
Icons.bluetooth,
),
const SizedBox(height: 18),
_infoRow(
'Voice Message',
widget.voiceAttached ? 'Attached' : 'Not Attached',
widget.voiceAttached ? Icons.mic : Icons.mic_off,
),
],
),
),
const SizedBox(height: 25),
Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(
vertical: 14,
horizontal: 16,
),
decoration: BoxDecoration(
color: alertColor.withValues(alpha: 0.10),
borderRadius: BorderRadius.circular(12),
border: Border.all(color: alertColor),
),
child: const Row(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(
Icons.warning_rounded,
color: alertColor,
),
SizedBox(width: 8),
Text(
'SOS ACTIVE',
style: TextStyle(
color: alertColor,
fontWeight: FontWeight.bold,
fontSize: 16,
),
),
],
),
),
const SizedBox(height: 18),
SizedBox(
width: double.infinity,
height: 55,
child: ElevatedButton(
onPressed: _stopping ? null : _stopSOS,
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
child: _stopping
? const SizedBox(
width: 23,
height: 23,
child: CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2,
),
)
    : const Text(
'STOP SOS',
style: TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
),
),
const SizedBox(height: 12),
SizedBox(
width: double.infinity,
height: 52,
child: OutlinedButton(
onPressed: () => Navigator.pop(context),
style: OutlinedButton.styleFrom(
foregroundColor: Colors.black87,
side: const BorderSide(color: Colors.grey),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
child: const Text(
'BACK',
style: TextStyle(
fontSize: 15,
fontWeight: FontWeight.bold,
),
),
),
),
],
),
),
),
),
);
}

Widget _infoRow(
String title,
String value,
IconData icon,
) {
return Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 42,
height: 42,
decoration: BoxDecoration(
color: Colors.grey.withValues(alpha: 0.08),
borderRadius: BorderRadius.circular(10),
),
child: Icon(
icon,
color: Colors.black54,
size: 21,
),
),
const SizedBox(width: 12),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
title,
style: const TextStyle(
color: Colors.grey,
fontSize: 12,
),
),
const SizedBox(height: 4),
Text(
value,
style: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
),
),
],
),
),
],
);
}
}
