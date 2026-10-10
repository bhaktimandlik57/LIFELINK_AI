
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LifelinkNetworkScreen extends StatefulWidget {
const LifelinkNetworkScreen({super.key});

@override
State<LifelinkNetworkScreen> createState() =>
_LifelinkNetworkScreenState();
}

class _LifelinkNetworkScreenState
extends State<LifelinkNetworkScreen> {
static const String lifelinkServiceUuid =
'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';

static const String lifelinkTxUuid =
defaultTxCharacteristicUuid;

static const String lifelinkRxUuid =
defaultRxCharacteristicUuid;

final FlutterBlePeripheral peripheral = FlutterBlePeripheral();
final AudioPlayer audioPlayer = AudioPlayer();
final List<ScanResult> nearbyDevices = [];
final BytesBuilder _voiceBuffer = BytesBuilder();

StreamSubscription<Uint8List>? peripheralReceiveSubscription;
StreamSubscription<List<ScanResult>>? scanSubscription;

bool isScanning = false;
bool isAdvertising = false;
bool isSending = false;

String relayStatus = 'Waiting for network';

Map<String, dynamic>? receivedSosData;
String? receivedVoicePath;

int _expectedVoiceLength = 0;
bool _receivingVoice = false;

// ------------------------------------------------------------
// INIT
// ------------------------------------------------------------

@override
void initState() {
super.initState();
_startPeripheralListener();
_loadPreviouslyReceivedData();
}

Future<void> _loadPreviouslyReceivedData() async {
try {
final prefs = await SharedPreferences.getInstance();
final sosString = prefs.getString('received_sos');
final voicePath = prefs.getString('received_voice_path');

if (!mounted) return;

setState(() {
if (sosString != null && sosString.isNotEmpty) {
try {
receivedSosData =
jsonDecode(sosString) as Map<String, dynamic>;
} catch (_) {}
}

if (voicePath != null &&
voicePath.isNotEmpty &&
File(voicePath).existsSync()) {
receivedVoicePath = voicePath;
}
});
} catch (_) {}
}

// ------------------------------------------------------------
// DISPOSE
// ------------------------------------------------------------

@override
void dispose() {
scanSubscription?.cancel();
peripheralReceiveSubscription?.cancel();
audioPlayer.dispose();

try {
FlutterBluePlus.stopScan();
} catch (_) {}

try {
peripheral.stop();
} catch (_) {}

super.dispose();
}

// ------------------------------------------------------------
// PERIPHERAL RECEIVER
// ------------------------------------------------------------

void _startPeripheralListener() {
peripheralReceiveSubscription =
peripheral.onDataReceived.listen(
(Uint8List bytes) {
_handleIncomingBytes(bytes);
},
onError: (_) {},
);
}

// ------------------------------------------------------------
// START LIFELINK NETWORK
// ------------------------------------------------------------

Future<void> startAdvertising() async {
try {
await peripheral.requestPermission();

await peripheral.start(
advertiseData: const AdvertiseDataCore(
serviceUuid: lifelinkServiceUuid,
localName: 'LIFELINK',
),
gattServer: const GattServerSettings(
serviceUuid: lifelinkServiceUuid,
txCharacteristicUuid: lifelinkTxUuid,
rxCharacteristicUuid: lifelinkRxUuid,
),
);

if (!mounted) return;

setState(() {
isAdvertising = true;
relayStatus = 'LIFELINK Network active';
});
} catch (e) {
if (!mounted) return;

setState(() {
relayStatus = 'BLE error: $e';
});
}
}

// ------------------------------------------------------------
// STOP LIFELINK NETWORK
// ------------------------------------------------------------

Future<void> stopAdvertising() async {
try {
await peripheral.stop();
} catch (_) {}

if (!mounted) return;

setState(() {
isAdvertising = false;
relayStatus = 'Waiting for network';
});
}

// ------------------------------------------------------------
// SCAN FOR NEARBY LIFELINK DEVICES
// ------------------------------------------------------------

Future<void> scanForDevices() async {
if (isScanning) return;

try {
if (mounted) {
setState(() {
isScanning = true;
nearbyDevices.clear();
relayStatus = 'Scanning for LIFELINK devices...';
});
}

var adapterState = await FlutterBluePlus.adapterState.first;

if (adapterState != BluetoothAdapterState.on &&
Platform.isAndroid) {
try {
await FlutterBluePlus.turnOn();
} catch (_) {}

adapterState = await FlutterBluePlus.adapterState.first;
}

if (adapterState != BluetoothAdapterState.on) {
if (mounted) {
setState(() {
relayStatus =
'Bluetooth is off. Enable Bluetooth to relay SOS.';
});
}
return;
}

await scanSubscription?.cancel();

scanSubscription = FlutterBluePlus.onScanResults.listen(
(results) {
for (final result in results) {
final alreadyAdded = nearbyDevices.any(
(device) =>
device.device.remoteId ==
result.device.remoteId,
);

if (!alreadyAdded && mounted) {
setState(() {
nearbyDevices.add(result);
});
}
}
},
onError: (_) {},
);

await FlutterBluePlus.startScan(
withServices: [Guid(lifelinkServiceUuid)],
timeout: const Duration(seconds: 4),
androidUsesFineLocation: true,
);

try {
await FlutterBluePlus.stopScan();
} catch (_) {}

await scanSubscription?.cancel();
scanSubscription = null;

if (mounted) {
setState(() {
relayStatus = nearbyDevices.isEmpty
? 'No LIFELINK device found'
    : '${nearbyDevices.length} LIFELINK device(s) found';
});
}
} catch (e) {
try {
await FlutterBluePlus.stopScan();
} catch (_) {}

await scanSubscription?.cancel();
scanSubscription = null;

if (mounted) {
setState(() {
relayStatus = 'Scan error: $e';
});
}
} finally {
if (mounted) {
setState(() {
isScanning = false;
});
}
}
}

// ------------------------------------------------------------
// SEND LATEST SOS
// ------------------------------------------------------------

Future<void> sendLatestSOS() async {
if (isSending) return;

BluetoothDevice? connectedDevice;

try {
final prefs = await SharedPreferences.getInstance();
final sosString = prefs.getString('latest_sos');

if (sosString == null || sosString.isEmpty) {
_showMessage('No SOS data available.');
return;
}

final sosData =
jsonDecode(sosString) as Map<String, dynamic>;

// Find the voice recording attached to this SOS.
String? voicePath;
final storedVoicePath = sosData['voicePath'];

if (storedVoicePath != null &&
storedVoicePath.toString().isNotEmpty) {
final file = File(storedVoicePath.toString());

if (await file.exists()) {
voicePath = storedVoicePath.toString();
}
}

if (voicePath == null) {
final latestVoicePath =
prefs.getString('latest_voice_path');

if (latestVoicePath != null &&
latestVoicePath.isNotEmpty) {
final voiceFile = File(latestVoicePath);

if (await voiceFile.exists()) {
voicePath = latestVoicePath;
}
}
}

// Scan if no nearby device has been found yet.
if (nearbyDevices.isEmpty) {
await scanForDevices();
}

if (nearbyDevices.isEmpty) {
_showMessage('No nearby LIFELINK device found.');
return;
}

if (mounted) {
setState(() {
isSending = true;
relayStatus = 'Connecting to nearby device...';
});
}

final device = nearbyDevices.first.device;
connectedDevice = device;

await device.connect(
license: License.nonprofit,
timeout: const Duration(seconds: 20),
autoConnect: false,
);

final int mtu = device.mtuNow;

if (mounted) {
setState(() {
relayStatus = 'Connected • MTU $mtu';
});
}

// Discover LIFELINK services and RX characteristic.
final services = await device.discoverServices();
BluetoothCharacteristic? rxCharacteristic;

for (final service in services) {
if (service.uuid == Guid(lifelinkServiceUuid)) {
for (final characteristic in service.characteristics) {
if (characteristic.uuid == Guid(lifelinkRxUuid)) {
rxCharacteristic = characteristic;
break;
}
}
}

if (rxCharacteristic != null) break;
}

if (rxCharacteristic == null) {
throw Exception('LIFELINK RX characteristic not found');
}

if (!rxCharacteristic.properties.write) {
throw Exception('RX characteristic does not support write');
}

// Send SOS details.
final sosPacket = <String, dynamic>{
'packetType': 'LIFELINK_SOS',
'sosId': sosData['sosId'],
'type': sosData['type'],
'latitude': sosData['latitude'],
'longitude': sosData['longitude'],
'timestamp': sosData['timestamp'],
'status': 'RECEIVED',
'network': 'BLE_CONNECTED',
'voiceAttached': voicePath != null,
};

final jsonBytes = utf8.encode(jsonEncode(sosPacket));

await _writeInChunks(
rxCharacteristic,
Uint8List.fromList(jsonBytes),
);

// Send the actual voice recording, if attached.
if (voicePath != null) {
final file = File(voicePath);

if (await file.exists()) {
final audioBytes = await file.readAsBytes();

if (audioBytes.isEmpty) {
throw Exception('Voice file is empty');
}

if (mounted) {
setState(() {
relayStatus =
'Sending voice • ${(audioBytes.length / 1024).round()} KB';
});
}

await _sendVoiceFile(
rxCharacteristic,
audioBytes,
mtu,
);
}
}

await device.disconnect();
connectedDevice = null;

final updatedSos = Map<String, dynamic>.from(sosData);
updatedSos['status'] = 'SENT';
updatedSos['network'] = 'BLE_CONNECTED';

await prefs.setString(
'latest_sos',
jsonEncode(updatedSos),
);

if (mounted) {
setState(() {
isSending = false;
relayStatus = 'SOS and voice sent successfully';
});
}

_showMessage(
voicePath != null
? 'SOS and voice sent successfully.'
    : 'SOS sent successfully. No voice attached.',
);
} catch (e) {
try {
await connectedDevice?.disconnect();
} catch (_) {}

if (mounted) {
setState(() {
isSending = false;
relayStatus = 'Send failed';
});
}

_showMessage('Send error: $e');
}
}

// ------------------------------------------------------------
// WRITE SOS JSON IN CHUNKS
// ------------------------------------------------------------

Future<void> _writeInChunks(
BluetoothCharacteristic characteristic,
Uint8List data,
) async {
const int chunkSize = 100;

for (int i = 0; i < data.length; i += chunkSize) {
final int end =
(i + chunkSize < data.length)
? i + chunkSize
    : data.length;

await characteristic.write(
data.sublist(i, end),
withoutResponse: false,
timeout: 30,
);
}
}

// ------------------------------------------------------------
// SEND VOICE FILE
// ------------------------------------------------------------

Future<void> _sendVoiceFile(
BluetoothCharacteristic characteristic,
Uint8List audioBytes,
int mtu,
) async {
// Start frame: LLV1 + audio length.
final ByteData startData = ByteData(8);

startData.setUint32(0, 0x4C4C5631, Endian.big);
startData.setUint32(4, audioBytes.length, Endian.big);

await characteristic.write(
startData.buffer.asUint8List(),
withoutResponse: false,
timeout: 30,
);

int audioChunkSize = mtu - 8;

if (audioChunkSize < 50) audioChunkSize = 50;
if (audioChunkSize > 180) audioChunkSize = 180;

for (int i = 0; i < audioBytes.length; i += audioChunkSize) {
final int end =
(i + audioChunkSize < audioBytes.length)
? i + audioChunkSize
    : audioBytes.length;

final Uint8List audioChunk = audioBytes.sublist(i, end);
final Uint8List packet = Uint8List(5 + audioChunk.length);

// C marker + 4-byte offset + audio bytes.
packet[0] = 0x43;

final ByteData offsetData = ByteData.sublistView(packet);
offsetData.setUint32(1, i, Endian.big);

packet.setRange(5, packet.length, audioChunk);

await characteristic.write(
packet,
withoutResponse: false,
timeout: 30,
);

await Future.delayed(const Duration(milliseconds: 3));
}

// End frame: ELLV1.
final Uint8List endPacket = Uint8List.fromList([
0x45,
0x4C,
0x4C,
0x56,
0x31,
]);

await characteristic.write(
endPacket,
withoutResponse: false,
timeout: 30,
);
}

// ------------------------------------------------------------
// RECEIVE DATA
// ------------------------------------------------------------

Future<void> _handleIncomingBytes(Uint8List bytes) async {
if (bytes.isEmpty) return;

// Voice start frame.
if (bytes.length == 8 &&
bytes[0] == 0x4C &&
bytes[1] == 0x4C &&
bytes[2] == 0x56 &&
bytes[3] == 0x31) {
final ByteData data = ByteData.sublistView(bytes);

_expectedVoiceLength = data.getUint32(4, Endian.big);
_voiceBuffer.clear();
_receivingVoice = true;

if (mounted) {
setState(() {
relayStatus = 'Receiving voice message...';
});
}

return;
}

// Voice data chunk.
if (_receivingVoice &&
bytes.length >= 5 &&
bytes[0] == 0x43) {
final Uint8List audioPart = bytes.sublist(5);
_voiceBuffer.add(audioPart);

if (mounted) {
setState(() {
relayStatus =
'Receiving voice • ${_voiceBuffer.length} / $_expectedVoiceLength bytes';
});
}

return;
}

// Voice end frame.
if (_receivingVoice &&
bytes.length == 5 &&
bytes[0] == 0x45 &&
bytes[1] == 0x4C &&
bytes[2] == 0x4C &&
bytes[3] == 0x56 &&
bytes[4] == 0x31) {
await _finishVoiceReceive();
return;
}

// SOS JSON packet.
try {
final String text = utf8.decode(
bytes,
allowMalformed: false,
);

if (!text.contains('LIFELINK_SOS')) return;

final Map<String, dynamic> data =
jsonDecode(text) as Map<String, dynamic>;

await _receiveSOS(data);
} catch (_) {
// Ignore invalid or incomplete packets.
}
}

// ------------------------------------------------------------
// FINISH VOICE RECEIVE
// ------------------------------------------------------------

Future<void> _finishVoiceReceive() async {
final Uint8List audioBytes = _voiceBuffer.takeBytes();
_receivingVoice = false;

if (audioBytes.isEmpty) {
if (mounted) {
setState(() {
relayStatus = 'Voice transfer failed: empty audio';
});
}
return;
}

if (_expectedVoiceLength > 0 &&
audioBytes.length != _expectedVoiceLength) {
if (mounted) {
setState(() {
relayStatus =
'Voice received partially (${audioBytes.length}/$_expectedVoiceLength bytes)';
});
}
return;
}

try {
final directory = await getApplicationDocumentsDirectory();

final path =
'${directory.path}/received_lifelink_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

final file = File(path);
await file.writeAsBytes(audioBytes, flush: true);

receivedVoicePath = path;

final prefs = await SharedPreferences.getInstance();
await prefs.setString('received_voice_path', path);

if (receivedSosData != null) {
receivedSosData =
Map<String, dynamic>.from(receivedSosData!);

receivedSosData!['voiceAttached'] = true;

await prefs.setString(
'received_sos',
jsonEncode(receivedSosData),
);
}

if (mounted) {
setState(() {
relayStatus = 'SOS and voice received';
});
}
} catch (e) {
if (mounted) {
setState(() {
relayStatus = 'Voice save failed: $e';
});
}
}
}

// ------------------------------------------------------------
// RECEIVE SOS
// ------------------------------------------------------------

Future<void> _receiveSOS(Map<String, dynamic> data) async {
final sosId = data['sosId']?.toString();
final prefs = await SharedPreferences.getInstance();

final previousId = prefs.getString('last_received_sos_id');

if (sosId != null &&
sosId == previousId &&
data['voiceAttached'] != true) {
return;
}

if (sosId != null) {
await prefs.setString('last_received_sos_id', sosId);
}

final receivedData = Map<String, dynamic>.from(data);
receivedData['status'] = 'RECEIVED';
receivedData['network'] = 'BLE_CONNECTED';

await prefs.setString(
'received_sos',
jsonEncode(receivedData),
);

if (mounted) {
setState(() {
receivedSosData = receivedData;
relayStatus = data['voiceAttached'] == true
? 'SOS received • Waiting for voice'
    : 'SOS received';
});
}
}

// ------------------------------------------------------------
// PLAY RECEIVED VOICE
// ------------------------------------------------------------

Future<void> playReceivedVoice() async {
String? path = receivedVoicePath;

if (path == null || path.isEmpty) {
final prefs = await SharedPreferences.getInstance();
path = prefs.getString('received_voice_path');
}

if (path == null || path.isEmpty) {
_showMessage('No voice message received.');
return;
}

final file = File(path);

if (!await file.exists()) {
_showMessage('Voice file not found.');
return;
}

try {
await audioPlayer.stop();
await audioPlayer.play(DeviceFileSource(path));
} catch (e) {
_showMessage('Unable to play voice: $e');
}
}

// ------------------------------------------------------------
// MESSAGE
// ------------------------------------------------------------

void _showMessage(String message) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}

// ------------------------------------------------------------
// DEVICE NAME
// ------------------------------------------------------------

String _deviceName(ScanResult result) {
final name = result.advertisementData.advName;

if (name.isNotEmpty) return name;

final platformName = result.device.platformName;

if (platformName.isNotEmpty) return platformName;

return 'LIFELINK Device';
}

// ------------------------------------------------------------
// UI
// ------------------------------------------------------------

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text('LIFELINK Network'),
centerTitle: true,
),
body: SafeArea(
child: RefreshIndicator(
onRefresh: scanForDevices,
child: ListView(
padding: const EdgeInsets.all(20),
children: [
Card(
child: Padding(
padding: const EdgeInsets.all(18),
child: Row(
children: [
Icon(
isAdvertising
? Icons.bluetooth_connected
    : Icons.bluetooth,
size: 35,
),
const SizedBox(width: 15),
Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Text(
'LIFELINK Network',
style: TextStyle(
fontSize: 18,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 5),
Text(relayStatus),
],
),
),
],
),
),
),

const SizedBox(height: 20),

SizedBox(
height: 52,
child: ElevatedButton.icon(
onPressed: isAdvertising
? stopAdvertising
    : startAdvertising,
icon: Icon(
isAdvertising
? Icons.stop
    : Icons.wifi_tethering,
),
label: Text(
isAdvertising
? 'Stop LIFELINK Network'
    : 'Start LIFELINK Network',
),
),
),

const SizedBox(height: 12),

SizedBox(
height: 52,
child: OutlinedButton.icon(
onPressed: isScanning ? null : scanForDevices,
icon: const Icon(Icons.search),
label: Text(
isScanning
? 'Scanning...'
    : 'Find Nearby LIFELINK Devices',
),
),
),

const SizedBox(height: 20),

SizedBox(
height: 55,
child: ElevatedButton.icon(
onPressed: isSending ? null : sendLatestSOS,
icon: const Icon(Icons.sos),
label: Text(
isSending
? 'Sending SOS...'
    : 'Send Latest SOS',
),
),
),

const SizedBox(height: 25),

if (nearbyDevices.isNotEmpty) ...[
const Text(
'Nearby Devices',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
],

...nearbyDevices.map(
(result) => Card(
child: ListTile(
leading: const Icon(Icons.bluetooth),
title: Text(_deviceName(result)),
subtitle: Text(
result.device.remoteId.toString(),
),
),
),
),

if (receivedSosData != null) ...[
const SizedBox(height: 25),

const Text(
'Received SOS',
style: TextStyle(
fontSize: 22,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 10),

Card(
child: Padding(
padding: const EdgeInsets.all(18),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(
'Emergency Type: '
'${receivedSosData!['type'] ?? 'Unknown'}',
style: const TextStyle(
fontSize: 17,
fontWeight: FontWeight.bold,
),
),

const SizedBox(height: 10),

Text(
'SOS ID: ${receivedSosData!['sosId'] ?? '-'}',
),

const SizedBox(height: 8),

Text(
'Latitude: ${receivedSosData!['latitude'] ?? '-'}',
),

const SizedBox(height: 8),

Text(
'Longitude: ${receivedSosData!['longitude'] ?? '-'}',
),

const SizedBox(height: 8),

Text(
'Network: ${receivedSosData!['network'] ?? '-'}',
),

const SizedBox(height: 18),

if (_receivingVoice)
Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.orange),
),
child: const Row(
children: [
Icon(Icons.mic, color: Colors.orange),
SizedBox(width: 10),
Expanded(
child: Text(
'Receiving voice message...',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
),
SizedBox(
width: 20,
height: 20,
child: CircularProgressIndicator(
strokeWidth: 2,
),
),
],
),
),

if (!_receivingVoice &&
receivedVoicePath != null)
Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.green),
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
const Row(
children: [
Icon(Icons.mic, color: Colors.green),
SizedBox(width: 10),
Expanded(
child: Text(
'Voice Message Received',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
),
],
),

const SizedBox(height: 12),

SizedBox(
width: double.infinity,
height: 50,
child: ElevatedButton.icon(
onPressed: playReceivedVoice,
icon: const Icon(Icons.play_arrow),
label: const Text(
'Play Received Voice',
),
),
),
],
),
),

if (!_receivingVoice &&
receivedVoicePath == null &&
receivedSosData!['voiceAttached'] == true)
Container(
width: double.infinity,
padding: const EdgeInsets.all(14),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.orange),
),
child: const Row(
children: [
Icon(
Icons.hourglass_empty,
color: Colors.orange,
),
SizedBox(width: 10),
Expanded(
child: Text(
'Voice message is being received...',
style: TextStyle(
fontWeight: FontWeight.bold,
),
),
),
],
),
),
],
),
),
),
],
],
),
),
),
);
}
}
