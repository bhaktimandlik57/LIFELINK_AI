
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
import 'package:permission_handler/permission_handler.dart';

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

static const String lifelinkTxUuid = defaultTxCharacteristicUuid;
static const String lifelinkRxUuid = defaultRxCharacteristicUuid;

static const int sosMagic = 0x4C4C5331; // LLS1
static const int voiceMagic = 0x4C4C5631; // LLV1

final FlutterBlePeripheral peripheral = FlutterBlePeripheral();
final AudioPlayer audioPlayer = AudioPlayer();
final List<ScanResult> nearbyDevices = [];

final BytesBuilder _sosBuffer = BytesBuilder();
final BytesBuilder _voiceBuffer = BytesBuilder();

StreamSubscription<Uint8List>? peripheralReceiveSubscription;
StreamSubscription<List<ScanResult>>? scanSubscription;

bool isScanning = false;
bool isAdvertising = false;
bool isSending = false;
bool _receivingSos = false;
bool _receivingVoice = false;
bool _isDeletingSos = false;

String relayStatus = 'Waiting for network';

Map<String, dynamic>? receivedSosData;
String? receivedVoicePath;

int _expectedSosLength = 0;
int _expectedVoiceLength = 0;
int _nextSosOffset = 0;
int _nextVoiceOffset = 0;

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
// BLE RECEIVER
// ------------------------------------------------------------

void _startPeripheralListener() {
peripheralReceiveSubscription =
peripheral.onDataReceived.listen(
(bytes) {
_handleIncomingBytes(bytes);
},
onError: (Object error) {
if (mounted) {
setState(() {
relayStatus = 'BLE receive error: $error';
});
}
},
);
}

// ------------------------------------------------------------
// START NETWORK
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
relayStatus = 'BLE advertising error: $e';
});
}
}

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
// SCAN FOR LIFELINK DEVICES
// ------------------------------------------------------------



  Future<void> scanForDevices() async {
    if (isScanning) return;

    try {
      setState(() {
        isScanning = true;
        nearbyDevices.clear();
        relayStatus = 'Checking Bluetooth permissions...';
      });

      // Request permissions needed for BLE scanning.
      if (Platform.isAndroid) {
        final scanPermission = await Permission.bluetoothScan.request();
        final connectPermission =
        await Permission.bluetoothConnect.request();

        // Android 11 and older also need location permission.
        PermissionStatus locationPermission = PermissionStatus.granted;
        if (await Permission.locationWhenInUse.isDenied) {
          locationPermission =
          await Permission.locationWhenInUse.request();
        } else {
          locationPermission =
          await Permission.locationWhenInUse.status;
        }

        if (!scanPermission.isGranted ||
            !connectPermission.isGranted) {
          throw Exception(
            'Allow Nearby devices permission in phone Settings.',
          );
        }

        if (await Permission.bluetoothScan.isPermanentlyDenied ||
            await Permission.bluetoothConnect.isPermanentlyDenied) {
          throw Exception(
            'Bluetooth permission is permanently denied. '
                'Enable Nearby devices in Settings.',
          );
        }

        // Location is needed for scanning on Android 11 and older.
        if (await Permission.locationWhenInUse.isDenied &&
            !locationPermission.isGranted) {
          throw Exception(
            'Allow Location permission for Bluetooth scanning.',
          );
        }
      }

      final adapterState = await FlutterBluePlus.adapterState.first;

      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Turn on Bluetooth and try again.');
      }

      await scanSubscription?.cancel();

      scanSubscription = FlutterBluePlus.onScanResults.listen(
            (results) {
          for (final result in results) {
            // Display LIFELINK devices by advertised name or service UUID.
            final name =
            result.advertisementData.advName.toUpperCase();

            final hasName = name.contains('LIFELINK');

            final hasService =
            result.advertisementData.serviceUuids.any(
                  (uuid) =>
              uuid.str.toLowerCase() ==
                  lifelinkServiceUuid.toLowerCase(),
            );

            if (!hasName && !hasService) continue;

            final alreadyAdded = nearbyDevices.any(
                  (item) =>
              item.device.remoteId == result.device.remoteId,
            );

            if (!alreadyAdded && mounted) {
              setState(() {
                nearbyDevices.add(result);
                relayStatus =
                '${nearbyDevices.length} LIFELINK device(s) found';
              });
            }
          }
        },
        onError: (Object error) {
          if (mounted) {
            setState(() {
              relayStatus = 'Scan error: $error';
            });
          }
        },
      );

      setState(() {
        relayStatus = 'Scanning for 12 seconds...';
      });

      // IMPORTANT: Keep the scan running long enough to discover devices.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
      );

      await Future.delayed(const Duration(seconds: 12));

      await FlutterBluePlus.stopScan();
      await scanSubscription?.cancel();
      scanSubscription = null;

      if (mounted) {
        setState(() {
          relayStatus = nearbyDevices.isEmpty
              ? 'No LIFELINK devices found. Check receiver advertising.'
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
          relayStatus = 'Scan failed: $e';
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
// DELETE RECENT SOS
// ------------------------------------------------------------

Future<void> deleteRecentSOS() async {
if (isSending || _isDeletingSos) return;

final confirm = await showDialog<bool>(
context: context,
builder: (dialogContext) => AlertDialog(
title: const Text('Delete Recent SOS?'),
content: const Text(
'This will remove the SOS saved on this phone and clear '
'the saved voice-recording reference. It will not delete '
'SOS data already received on another phone.',
),
actions: [
TextButton(
onPressed: () =>
Navigator.pop(dialogContext, false),
child: const Text('Cancel'),
),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.red,
foregroundColor: Colors.white,
),
onPressed: () =>
Navigator.pop(dialogContext, true),
child: const Text('Delete'),
),
],
),
);

if (confirm != true) return;

if (!mounted) return;

setState(() {
_isDeletingSos = true;
relayStatus = 'Deleting saved SOS...';
});

try {
final prefs = await SharedPreferences.getInstance();

// Remove the outgoing SOS and stale recording reference.
await prefs.remove('latest_sos');
await prefs.remove('latest_voice_path');

if (!mounted) return;

setState(() {
relayStatus = 'Recent SOS deleted. Ready for a new SOS.';
});

_showMessage(
'Recent SOS deleted. You can create a new SOS now.',
);
} catch (e) {
if (mounted) {
setState(() {
relayStatus = 'Could not delete SOS.';
});
}

_showMessage('Unable to delete SOS: $e');
} finally {
if (mounted) {
setState(() {
_isDeletingSos = false;
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
_showMessage('No SOS data available. Create a new SOS first.');
return;
}

final sosData =
jsonDecode(sosString) as Map<String, dynamic>;

// Only use the voice path saved with this specific SOS.
String? voicePath;
final storedPath = sosData['voicePath'];

if (storedPath != null &&
storedPath.toString().isNotEmpty) {
final file = File(storedPath.toString());

if (await file.exists()) {
voicePath = storedPath.toString();
}
}

if (nearbyDevices.isEmpty) {
await scanForDevices();
}

if (!mounted) return;

if (nearbyDevices.isEmpty) {
_showMessage('No nearby LIFELINK device found.');
return;
}

setState(() {
isSending = true;
relayStatus = 'Connecting to nearby device...';
});

final device = nearbyDevices.first.device;
connectedDevice = device;

await device.connect(
license: License.nonprofit,
timeout: const Duration(seconds: 20),
autoConnect: false,
);

final mtu = device.mtuNow;

if (mounted) {
setState(() {
relayStatus = 'Connected • MTU $mtu';
});
}

final services = await device.discoverServices();

BluetoothCharacteristic? rxCharacteristic;

for (final service in services) {
if (service.uuid != Guid(lifelinkServiceUuid)) continue;

for (final characteristic in service.characteristics) {
if (characteristic.uuid == Guid(lifelinkRxUuid)) {
rxCharacteristic = characteristic;
break;
}
}

if (rxCharacteristic != null) break;
}

if (rxCharacteristic == null) {
throw Exception(
'LIFELINK RX characteristic not found. '
'Check the receiver GATT configuration.',
);
}

if (!rxCharacteristic.properties.write) {
throw Exception(
'Receiver RX characteristic does not support writing.',
);
}

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

final sosBytes = Uint8List.fromList(
utf8.encode(jsonEncode(sosPacket)),
);

await _sendFramedData(
rxCharacteristic,
sosBytes,
mtu,
dataMarker: 0x53,
startMagic: sosMagic,
endMagic: const [0x45, 0x4C, 0x4C, 0x53, 0x31],
);

if (voicePath != null) {
final voiceFile = File(voicePath);

if (await voiceFile.exists()) {
final audioBytes = await voiceFile.readAsBytes();

if (audioBytes.isEmpty) {
throw Exception('Voice recording is empty.');
}

if (mounted) {
setState(() {
relayStatus =
'Sending voice • ${(audioBytes.length / 1024).round()} KB';
});
}

await _sendFramedData(
rxCharacteristic,
audioBytes,
mtu,
dataMarker: 0x43,
startMagic: voiceMagic,
endMagic: const [0x45, 0x4C, 0x4C, 0x56, 0x31],
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
relayStatus = 'SOS transfer completed';
});
}

_showMessage(
voicePath != null
? 'SOS and voice transfer completed.'
    : 'SOS transfer completed. No voice attached.',
);
} catch (e) {
try {
await connectedDevice?.disconnect();
} catch (_) {}

if (mounted) {
setState(() {
isSending = false;
relayStatus = 'Send failed: $e';
});
}

_showMessage('Send error: $e');
} finally {
if (mounted && isSending) {
setState(() {
isSending = false;
});
}
}
}

// ------------------------------------------------------------
// SEND FRAMED SOS OR VOICE DATA
// ------------------------------------------------------------

Future<void> _sendFramedData(
BluetoothCharacteristic characteristic,
Uint8List data,
int mtu, {
required int dataMarker,
required int startMagic,
required List<int> endMagic,
}) async {
final start = ByteData(8);
start.setUint32(0, startMagic, Endian.big);
start.setUint32(4, data.length, Endian.big);

await characteristic.write(
start.buffer.asUint8List(),
withoutResponse: false,
timeout: 30,
);

final chunkSize = mtu - 8;

if (chunkSize <= 0) {
throw Exception('Invalid BLE MTU: $mtu');
}

for (int offset = 0; offset < data.length; offset += chunkSize) {
final end = (offset + chunkSize < data.length)
? offset + chunkSize
    : data.length;

final part = data.sublist(offset, end);
final packet = Uint8List(5 + part.length);

packet[0] = dataMarker;

final header = ByteData.sublistView(packet);
header.setUint32(1, offset, Endian.big);

packet.setRange(5, packet.length, part);

await characteristic.write(
packet,
withoutResponse: false,
timeout: 30,
);

await Future.delayed(
const Duration(milliseconds: 3),
);
}

await characteristic.write(
endMagic,
withoutResponse: false,
timeout: 30,
);
}

// ------------------------------------------------------------
// RECEIVE FRAMED DATA
// ------------------------------------------------------------

Future<void> _handleIncomingBytes(Uint8List bytes) async {
if (bytes.isEmpty) return;

if (bytes.length == 8) {
final header = ByteData.sublistView(bytes);
final magic = header.getUint32(0, Endian.big);
final length = header.getUint32(4, Endian.big);

if (length == 0 || length > 20 * 1024 * 1024) {
return;
}

if (magic == sosMagic) {
_expectedSosLength = length;
_sosBuffer.clear();
_nextSosOffset = 0;
_receivingSos = true;
_receivingVoice = false;

if (mounted) {
setState(() {
relayStatus = 'Receiving SOS data...';
});
}
return;
}

if (magic == voiceMagic) {
_expectedVoiceLength = length;
_voiceBuffer.clear();
_nextVoiceOffset = 0;
_receivingVoice = true;
_receivingSos = false;

if (mounted) {
setState(() {
relayStatus = 'Receiving voice message...';
});
}
return;
}
}

if (_receivingSos &&
bytes.length == 5 &&
bytes[0] == 0x45 &&
bytes[1] == 0x4C &&
bytes[2] == 0x4C &&
bytes[3] == 0x53 &&
bytes[4] == 0x31) {
await _finishSosReceive();
return;
}

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

if (_receivingSos &&
bytes.length >= 5 &&
bytes[0] == 0x53) {
final header = ByteData.sublistView(bytes);
final offset = header.getUint32(1, Endian.big);

if (offset != _nextSosOffset) {
_receivingSos = false;
_sosBuffer.clear();

if (mounted) {
setState(() {
relayStatus = 'SOS transfer failed: missing chunk';
});
}
return;
}

final part = bytes.sublist(5);
_sosBuffer.add(part);
_nextSosOffset += part.length;
return;
}

if (_receivingVoice &&
bytes.length >= 5 &&
bytes[0] == 0x43) {
final header = ByteData.sublistView(bytes);
final offset = header.getUint32(1, Endian.big);

if (offset != _nextVoiceOffset) {
_receivingVoice = false;
_voiceBuffer.clear();

if (mounted) {
setState(() {
relayStatus = 'Voice transfer failed: missing chunk';
});
}
return;
}

final part = bytes.sublist(5);
_voiceBuffer.add(part);
_nextVoiceOffset += part.length;
}
}

// ------------------------------------------------------------
// FINISH SOS RECEIVE
// ------------------------------------------------------------

Future<void> _finishSosReceive() async {
final bytes = _sosBuffer.takeBytes();
_receivingSos = false;

if (bytes.length != _expectedSosLength) {
if (mounted) {
setState(() {
relayStatus =
'SOS incomplete: ${bytes.length}/$_expectedSosLength bytes';
});
}
return;
}

try {
final data =
jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

if (data['packetType'] != 'LIFELINK_SOS') {
throw const FormatException('Invalid SOS packet');
}

await _receiveSOS(data);
} catch (e) {
if (mounted) {
setState(() {
relayStatus = 'Invalid SOS data: $e';
});
}
}
}

// ------------------------------------------------------------
// FINISH VOICE RECEIVE
// ------------------------------------------------------------

Future<void> _finishVoiceReceive() async {
final audioBytes = _voiceBuffer.takeBytes();
_receivingVoice = false;

if (audioBytes.isEmpty ||
audioBytes.length != _expectedVoiceLength) {
if (mounted) {
setState(() {
relayStatus =
'Voice incomplete: ${audioBytes.length}/$_expectedVoiceLength bytes';
});
}
return;
}

try {
final directory = await getApplicationDocumentsDirectory();

final path =
'${directory.path}/received_lifelink_voice_'
'${DateTime.now().millisecondsSinceEpoch}.m4a';

final file = File(path);
await file.writeAsBytes(audioBytes, flush: true);

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

if (!mounted) return;

setState(() {
receivedVoicePath = path;
relayStatus = 'SOS and voice received';
});
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
final prefs = await SharedPreferences.getInstance();
final sosId = data['sosId']?.toString();

final receivedData = Map<String, dynamic>.from(data);
receivedData['status'] = 'RECEIVED';
receivedData['network'] = 'BLE_CONNECTED';

await prefs.setString(
'received_sos',
jsonEncode(receivedData),
);

if (sosId != null) {
await prefs.setString('last_received_sos_id', sosId);
}

if (!mounted) return;

setState(() {
receivedSosData = receivedData;
relayStatus = 'SOS received';
});
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

if (!await File(path).exists()) {
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

void _showMessage(String message) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text(message)),
);
}

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
crossAxisAlignment:
CrossAxisAlignment.start,
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
isSending ? 'Sending SOS...' : 'Send Latest SOS',
),
),
),
const SizedBox(height: 10),

SizedBox(
height: 50,
child: OutlinedButton.icon(
onPressed: (isSending || _isDeletingSos)
? null
    : deleteRecentSOS,
icon: const Icon(
Icons.delete_outline,
color: Colors.red,
),
label: Text(
_isDeletingSos
? 'Deleting SOS...'
    : 'Delete Recent SOS',
style: const TextStyle(color: Colors.red),
),
style: OutlinedButton.styleFrom(
side: const BorderSide(color: Colors.red),
),
),
),

if (nearbyDevices.isNotEmpty) ...[
const SizedBox(height: 25),
const Text(
'Nearby Devices',
style: TextStyle(
fontSize: 20,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
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
],

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
const ListTile(
leading: CircularProgressIndicator(),
title: Text('Receiving voice message...'),
),

if (!_receivingVoice &&
receivedVoicePath != null)
SizedBox(
width: double.infinity,
height: 50,
child: ElevatedButton.icon(
onPressed: playReceivedVoice,
icon: const Icon(Icons.play_arrow),
label: const Text('Play Received Voice'),
),
),

if (!_receivingVoice &&
receivedVoicePath == null &&
receivedSosData!['voiceAttached'] == true)
const ListTile(
leading: Icon(
Icons.hourglass_empty,
color: Colors.orange,
),
title: Text(
'Waiting for voice message...',
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
