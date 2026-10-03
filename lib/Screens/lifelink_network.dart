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
  // ============================================================
  // LIFELINK BLE UUID
  // ============================================================

  static const String lifelinkServiceUuid =
      'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';

  static const String lifelinkTxUuid =
      defaultTxCharacteristicUuid;

  static const String lifelinkRxUuid =
      defaultRxCharacteristicUuid;

  final FlutterBlePeripheral peripheral =
  FlutterBlePeripheral();

  StreamSubscription<Uint8List>?
  peripheralReceiveSubscription;

  StreamSubscription<List<ScanResult>>?
  scanSubscription;

  final List<ScanResult> nearbyDevices = [];

  bool isScanning = false;
  bool isAdvertising = false;
  bool isSending = false;

  String relayStatus = 'Waiting for network';

  Map<String, dynamic>? receivedSosData;

  String? receivedVoicePath;

  final AudioPlayer audioPlayer = AudioPlayer();

  // ============================================================
  // VOICE RECEIVING
  // ============================================================

  final BytesBuilder _voiceBuffer =
  BytesBuilder();

  int _expectedVoiceLength = 0;

  bool _receivingVoice = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _startPeripheralListener();

    _loadPreviouslyReceivedData();
  }

  // ============================================================
  // LOAD SAVED RECEIVED DATA
  // ============================================================

  Future<void> _loadPreviouslyReceivedData() async {
    try {
      final prefs =
      await SharedPreferences.getInstance();

      final sosString =
      prefs.getString('received_sos');

      final voicePath =
      prefs.getString('received_voice_path');

      if (!mounted) return;

      setState(() {
        if (sosString != null &&
            sosString.isNotEmpty) {
          try {
            receivedSosData =
            jsonDecode(sosString)
            as Map<String, dynamic>;
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

  // ============================================================
  // DISPOSE
  // ============================================================

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

  // ============================================================
  // PERIPHERAL RECEIVER
  // ============================================================

  void _startPeripheralListener() {
    peripheralReceiveSubscription =
        peripheral.onDataReceived.listen(
              (Uint8List bytes) {
            _handleIncomingBytes(bytes);
          },
          onError: (_) {},
        );
  }

  // ============================================================
  // START LIFELINK NETWORK
  // ============================================================

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
          txCharacteristicUuid:
          lifelinkTxUuid,
          rxCharacteristicUuid:
          lifelinkRxUuid,
        ),
      );

      if (!mounted) return;

      setState(() {
        isAdvertising = true;
        relayStatus =
        'LIFELINK Network active';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        relayStatus = 'BLE error: $e';
      });
    }
  }

  // ============================================================
  // STOP LIFELINK NETWORK
  // ============================================================

  Future<void> stopAdvertising() async {
    try {
      await peripheral.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      isAdvertising = false;
      relayStatus =
      'Waiting for network';
    });
  }

  // ============================================================
  // SCAN FOR DEVICES
  // ============================================================

  Future<void> scanForDevices() async {
    if (isScanning) return;

    try {
      if (mounted) {
        setState(() {
          isScanning = true;

          nearbyDevices.clear();

          relayStatus =
          'Scanning for LIFELINK devices...';
        });
      }

      final adapterState =
      await FlutterBluePlus
          .adapterState
          .first;

      if (adapterState !=
          BluetoothAdapterState.on) {
        if (Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (_) {}
        }
      }

      await scanSubscription?.cancel();

      scanSubscription =
          FlutterBluePlus.onScanResults.listen(
                (results) {
              for (final result in results) {
                final alreadyAdded =
                nearbyDevices.any(
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
        withServices: [
          Guid(lifelinkServiceUuid),
        ],
        timeout:
        const Duration(seconds: 8),
        androidUsesFineLocation: true,
      );

      if (mounted) {
        setState(() {
          isScanning = false;

          if (nearbyDevices.isEmpty) {
            relayStatus =
            'No LIFELINK device found';
          } else {
            relayStatus =
            '${nearbyDevices.length} LIFELINK device(s) found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isScanning = false;

          relayStatus =
          'Scan error: $e';
        });
      }
    }
  }

  // ============================================================
  // SEND LATEST SOS
  // ============================================================

  Future<void> sendLatestSOS() async {
    if (isSending) return;

    BluetoothDevice? connectedDevice;

    try {
      final prefs =
      await SharedPreferences.getInstance();

      final sosString =
      prefs.getString('latest_sos');

      if (sosString == null ||
          sosString.isEmpty) {
        _showMessage(
          'No SOS data available.',
        );
        return;
      }

      final sosData =
      jsonDecode(sosString)
      as Map<String, dynamic>;

      // --------------------------------------------------------
      // CHECK VOICE FILE
      // --------------------------------------------------------

      String? voicePath;

      final storedVoicePath =
      sosData['voicePath'];

      if (storedVoicePath != null &&
          storedVoicePath
              .toString()
              .isNotEmpty) {
        final testFile =
        File(
          storedVoicePath.toString(),
        );

        if (await testFile.exists()) {
          voicePath =
              storedVoicePath.toString();
        }
      }

      // If SOS does not contain voicePath,
      // check latest_voice_path.
      if (voicePath == null) {
        final latestVoicePath =
        prefs.getString(
          'latest_voice_path',
        );

        if (latestVoicePath != null &&
            latestVoicePath.isNotEmpty) {
          final voiceFile =
          File(latestVoicePath);

          if (await voiceFile.exists()) {
            voicePath =
                latestVoicePath;
          }
        }
      }

      // --------------------------------------------------------
      // SCAN IF NEEDED
      // --------------------------------------------------------

      if (nearbyDevices.isEmpty) {
        await scanForDevices();
      }

      if (nearbyDevices.isEmpty) {
        _showMessage(
          'No nearby LIFELINK device found.',
        );
        return;
      }

      if (mounted) {
        setState(() {
          isSending = true;

          relayStatus =
          'Connecting to nearby device...';
        });
      }

      final device =
          nearbyDevices.first.device;

      connectedDevice = device;

      // --------------------------------------------------------
      // CONNECT
      // --------------------------------------------------------

      await device.connect(
        license: License.nonprofit,
        timeout:
        const Duration(seconds: 20),
        autoConnect: false,
      );

      // Do NOT manually request MTU.
      final int mtu = device.mtuNow;

      if (mounted) {
        setState(() {
          relayStatus =
          'Connected • MTU $mtu';
        });
      }

      // --------------------------------------------------------
      // DISCOVER SERVICES
      // --------------------------------------------------------

      final services =
      await device.discoverServices();

      BluetoothCharacteristic?
      rxCharacteristic;

      for (final service in services) {
        if (service.uuid ==
            Guid(lifelinkServiceUuid)) {
          for (final characteristic
          in service.characteristics) {
            if (characteristic.uuid ==
                Guid(lifelinkRxUuid)) {
              rxCharacteristic =
                  characteristic;

              break;
            }
          }
        }

        if (rxCharacteristic != null) {
          break;
        }
      }

      if (rxCharacteristic == null) {
        throw Exception(
          'LIFELINK RX characteristic not found',
        );
      }

      // --------------------------------------------------------
      // CHECK WRITE SUPPORT
      // --------------------------------------------------------

      if (!rxCharacteristic
          .properties
          .write) {
        throw Exception(
          'RX characteristic does not support write',
        );
      }

      // --------------------------------------------------------
      // SEND SOS JSON
      // --------------------------------------------------------

      final sosPacket = {
        'packetType':
        'LIFELINK_SOS',
        'sosId':
        sosData['sosId'],
        'type':
        sosData['type'],
        'latitude':
        sosData['latitude'],
        'longitude':
        sosData['longitude'],
        'timestamp':
        sosData['timestamp'],
        'status':
        'RECEIVED',
        'network':
        'BLE_CONNECTED',
        'voiceAttached':
        voicePath != null,
      };

      final jsonBytes =
      utf8.encode(
        jsonEncode(sosPacket),
      );

      await _writeInChunks(
        rxCharacteristic,
        Uint8List.fromList(
          jsonBytes,
        ),
      );

      // --------------------------------------------------------
      // SEND ACTUAL VOICE
      // --------------------------------------------------------

      if (voicePath != null) {
        final file =
        File(voicePath);

        if (await file.exists()) {
          final audioBytes =
          await file.readAsBytes();

          if (audioBytes.isEmpty) {
            throw Exception(
              'Voice file is empty',
            );
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

      // --------------------------------------------------------
      // DISCONNECT
      // --------------------------------------------------------

      await device.disconnect();

      connectedDevice = null;

      // --------------------------------------------------------
      // UPDATE SOS
      // --------------------------------------------------------

      final updatedSos =
      Map<String, dynamic>.from(
        sosData,
      );

      updatedSos['status'] =
      'SENT';

      updatedSos['network'] =
      'BLE_CONNECTED';

      await prefs.setString(
        'latest_sos',
        jsonEncode(updatedSos),
      );

      if (mounted) {
        setState(() {
          isSending = false;

          relayStatus =
          'SOS and voice sent successfully';
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

          relayStatus =
          'Send failed';
        });
      }

      _showMessage(
        'Send error: $e',
      );
    }
  }

  // ============================================================
  // SEND SOS JSON
  // ============================================================

  Future<void> _writeInChunks(
      BluetoothCharacteristic characteristic,
      Uint8List data,
      ) async {
    const int chunkSize = 100;

    for (
    int i = 0;
    i < data.length;
    i += chunkSize
    ) {
      final int end =
      (i + chunkSize < data.length)
          ? i + chunkSize
          : data.length;

      final chunk =
      data.sublist(i, end);

      await characteristic.write(
        chunk,
        withoutResponse: false,
        timeout: 30,
      );
    }
  }

  // ============================================================
  // SEND VOICE FILE
  // ============================================================

  Future<void> _sendVoiceFile(
      BluetoothCharacteristic characteristic,
      Uint8List audioBytes,
      int mtu,
      ) async {
    // ----------------------------------------------------------
    // START FRAME
    // ----------------------------------------------------------

    final ByteData startData =
    ByteData(8);

    // LLV1
    startData.setUint32(
      0,
      0x4C4C5631,
      Endian.big,
    );

    // Audio length
    startData.setUint32(
      4,
      audioBytes.length,
      Endian.big,
    );

    await characteristic.write(
      startData.buffer.asUint8List(),
      withoutResponse: false,
      timeout: 30,
    );

    // ----------------------------------------------------------
    // SAFE CHUNK SIZE
    // ----------------------------------------------------------

    int audioChunkSize =
        mtu - 8;

    if (audioChunkSize < 50) {
      audioChunkSize = 50;
    }

    if (audioChunkSize > 180) {
      audioChunkSize = 180;
    }

    // ----------------------------------------------------------
    // SEND AUDIO CHUNKS
    // ----------------------------------------------------------

    for (
    int i = 0;
    i < audioBytes.length;
    i += audioChunkSize
    ) {
      final int end =
      (i + audioChunkSize <
          audioBytes.length)
          ? i + audioChunkSize
          : audioBytes.length;

      final Uint8List audioChunk =
      audioBytes.sublist(
        i,
        end,
      );

      // 1 marker + 4 offset + audio
      final Uint8List packet =
      Uint8List(
        5 + audioChunk.length,
      );

      // C = chunk
      packet[0] = 0x43;

      final ByteData offsetData =
      ByteData.sublistView(
        packet,
      );

      offsetData.setUint32(
        1,
        i,
        Endian.big,
      );

      packet.setRange(
        5,
        packet.length,
        audioChunk,
      );

      await characteristic.write(
        packet,
        withoutResponse: false,
        timeout: 30,
      );

      // Small delay for receiver.
      await Future.delayed(
        const Duration(
          milliseconds: 3,
        ),
      );
    }

    // ----------------------------------------------------------
    // END FRAME
    // ----------------------------------------------------------

    final Uint8List endPacket =
    Uint8List.fromList([
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

  // ============================================================
  // RECEIVE DATA
  // ============================================================

  Future<void> _handleIncomingBytes(
      Uint8List bytes,
      ) async {
    if (bytes.isEmpty) return;

    // ----------------------------------------------------------
    // VOICE START
    // ----------------------------------------------------------

    if (bytes.length == 8 &&
        bytes[0] == 0x4C &&
        bytes[1] == 0x4C &&
        bytes[2] == 0x56 &&
        bytes[3] == 0x31) {
      final ByteData data =
      ByteData.sublistView(
        bytes,
      );

      _expectedVoiceLength =
          data.getUint32(
            4,
            Endian.big,
          );

      _voiceBuffer.clear();

      _receivingVoice = true;

      if (mounted) {
        setState(() {
          relayStatus =
          'Receiving voice message...';
        });
      }

      return;
    }

    // ----------------------------------------------------------
    // VOICE CHUNK
    // ----------------------------------------------------------

    if (_receivingVoice &&
        bytes.length >= 5 &&
        bytes[0] == 0x43) {
      final Uint8List audioPart =
      bytes.sublist(5);

      _voiceBuffer.add(
        audioPart,
      );

      if (mounted) {
        setState(() {
          relayStatus =
          'Receiving voice • ${_voiceBuffer.length} / $_expectedVoiceLength bytes';
        });
      }

      return;
    }

    // ----------------------------------------------------------
    // VOICE END
    // ----------------------------------------------------------

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

    // ----------------------------------------------------------
    // NORMAL SOS JSON
    // ----------------------------------------------------------

    try {
      final String text =
      utf8.decode(
        bytes,
        allowMalformed: false,
      );

      if (!text.contains(
        'LIFELINK_SOS',
      )) {
        return;
      }

      final Map<String, dynamic> data =
      jsonDecode(text)
      as Map<String, dynamic>;

      await _receiveSOS(data);
    } catch (_) {
      // Ignore invalid packets.
    }
  }

  // ============================================================
  // FINISH VOICE RECEIVE
  // ============================================================

  Future<void> _finishVoiceReceive() async {
    final Uint8List audioBytes =
    _voiceBuffer.takeBytes();

    _receivingVoice = false;

    // ----------------------------------------------------------
    // EMPTY AUDIO
    // ----------------------------------------------------------

    if (audioBytes.isEmpty) {
      if (mounted) {
        setState(() {
          relayStatus =
          'Voice transfer failed: empty audio';
        });
      }

      return;
    }

    // ----------------------------------------------------------
    // CHECK SIZE
    // ----------------------------------------------------------

    if (_expectedVoiceLength > 0 &&
        audioBytes.length !=
            _expectedVoiceLength) {
      if (mounted) {
        setState(() {
          relayStatus =
          'Voice received partially '
              '(${audioBytes.length}/$_expectedVoiceLength bytes)';
        });
      }

      return;
    }

    // ----------------------------------------------------------
    // SAVE AUDIO
    // ----------------------------------------------------------

    try {
      final directory =
      await getApplicationDocumentsDirectory();

      final path =
          '${directory.path}/received_lifelink_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final file =
      File(path);

      await file.writeAsBytes(
        audioBytes,
        flush: true,
      );

      // Store actual received voice path.
      receivedVoicePath = path;

      final prefs =
      await SharedPreferences.getInstance();

      await prefs.setString(
        'received_voice_path',
        path,
      );

      // --------------------------------------------------------
      // UPDATE RECEIVED SOS
      // --------------------------------------------------------

      if (receivedSosData != null) {
        receivedSosData =
        Map<String, dynamic>.from(
          receivedSosData!,
        );

        receivedSosData![
        'voiceAttached'] =
        true;

        await prefs.setString(
          'received_sos',
          jsonEncode(
            receivedSosData,
          ),
        );
      }

      if (mounted) {
        setState(() {
          relayStatus =
          'SOS and voice received';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          relayStatus =
          'Voice save failed: $e';
        });
      }
    }
  }

  // ============================================================
  // RECEIVE SOS
  // ============================================================

  Future<void> _receiveSOS(
      Map<String, dynamic> data,
      ) async {
    final sosId =
    data['sosId']?.toString();

    final prefs =
    await SharedPreferences.getInstance();

    // ----------------------------------------------------------
    // IMPORTANT:
    // Do NOT ignore the SOS if voice is attached.
    // ----------------------------------------------------------

    final previousId =
    prefs.getString(
      'last_received_sos_id',
    );

    if (sosId != null &&
        sosId == previousId &&
        data['voiceAttached'] != true) {
      return;
    }

    if (sosId != null) {
      await prefs.setString(
        'last_received_sos_id',
        sosId,
      );
    }

    final receivedData =
    Map<String, dynamic>.from(
      data,
    );

    receivedData['status'] =
    'RECEIVED';

    receivedData['network'] =
    'BLE_CONNECTED';

    await prefs.setString(
      'received_sos',
      jsonEncode(
        receivedData,
      ),
    );

    if (mounted) {
      setState(() {
        receivedSosData =
            receivedData;

        relayStatus =
        data['voiceAttached'] == true
            ? 'SOS received • Waiting for voice'
            : 'SOS received';
      });
    }
  }

  // ============================================================
  // PLAY RECEIVED VOICE
  // ============================================================

  Future<void> playReceivedVoice() async {
    String? path =
        receivedVoicePath;

    // Check SharedPreferences if needed.
    if (path == null ||
        path.isEmpty) {
      final prefs =
      await SharedPreferences.getInstance();

      path =
          prefs.getString(
            'received_voice_path',
          );
    }

    // ----------------------------------------------------------
    // NO FILE
    // ----------------------------------------------------------

    if (path == null ||
        path.isEmpty) {
      _showMessage(
        'No voice message received.',
      );

      return;
    }

    // ----------------------------------------------------------
    // FILE DOES NOT EXIST
    // ----------------------------------------------------------

    final file =
    File(path);

    if (!await file.exists()) {
      _showMessage(
        'Voice file not found.',
      );

      return;
    }

    // ----------------------------------------------------------
    // PLAY
    // ----------------------------------------------------------

    try {
      await audioPlayer.stop();

      await audioPlayer.play(
        DeviceFileSource(path),
      );
    } catch (e) {
      _showMessage(
        'Unable to play voice: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // DEVICE NAME
  // ============================================================

  String _deviceName(
      ScanResult result,
      ) {
    final name =
        result.advertisementData.advName;

    if (name.isNotEmpty) {
      return name;
    }

    final platformName =
        result.device.platformName;

    if (platformName.isNotEmpty) {
      return platformName;
    }

    return 'LIFELINK Device';
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'LIFELINK Network',
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh:
          scanForDevices,

          child: ListView(
            padding:
            const EdgeInsets.all(20),

            children: [
              // ==================================================
              // NETWORK STATUS
              // ==================================================

              Card(
                child: Padding(
                  padding:
                  const EdgeInsets.all(
                    18,
                  ),

                  child: Row(
                    children: [
                      Icon(
                        isAdvertising
                            ? Icons
                            .bluetooth_connected
                            : Icons.bluetooth,
                        size: 35,
                      ),

                      const SizedBox(
                        width: 15,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                          children: [
                            const Text(
                              'LIFELINK Network',

                              style:
                              TextStyle(
                                fontSize: 18,
                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            const SizedBox(
                              height: 5,
                            ),

                            Text(
                              relayStatus,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // START / STOP NETWORK
              // ==================================================

              SizedBox(
                height: 52,

                child:
                ElevatedButton.icon(
                  onPressed:
                  isAdvertising
                      ? stopAdvertising
                      : startAdvertising,

                  icon: Icon(
                    isAdvertising
                        ? Icons.stop
                        : Icons
                        .wifi_tethering,
                  ),

                  label: Text(
                    isAdvertising
                        ? 'Stop LIFELINK Network'
                        : 'Start LIFELINK Network',
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ==================================================
              // SCAN
              // ==================================================

              SizedBox(
                height: 52,

                child:
                OutlinedButton.icon(
                  onPressed:
                  isScanning
                      ? null
                      : scanForDevices,

                  icon: const Icon(
                    Icons.search,
                  ),

                  label: Text(
                    isScanning
                        ? 'Scanning...'
                        : 'Find Nearby LIFELINK Devices',
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ==================================================
              // SEND SOS
              // ==================================================

              SizedBox(
                height: 55,

                child:
                ElevatedButton.icon(
                  onPressed:
                  isSending
                      ? null
                      : sendLatestSOS,

                  icon: const Icon(
                    Icons.sos,
                  ),

                  label: Text(
                    isSending
                        ? 'Sending SOS...'
                        : 'Send Latest SOS',
                  ),
                ),
              ),

              const SizedBox(
                height: 25,
              ),

              // ==================================================
              // NEARBY DEVICES
              // ==================================================

              if (nearbyDevices
                  .isNotEmpty) ...[
                const Text(
                  'Nearby Devices',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),
              ],

              ...nearbyDevices.map(
                    (result) => Card(
                  child: ListTile(
                    leading:
                    const Icon(
                      Icons.bluetooth,
                    ),

                    title: Text(
                      _deviceName(
                        result,
                      ),
                    ),

                    subtitle: Text(
                      result.device
                          .remoteId
                          .toString(),
                    ),
                  ),
                ),
              ),

              // ==================================================
              // RECEIVED SOS
              // ==================================================

              if (receivedSosData !=
                  null) ...[
                const SizedBox(
                  height: 25,
                ),

                const Text(
                  'Received SOS',

                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Card(
                  child: Padding(
                    padding:
                    const EdgeInsets.all(
                      18,
                    ),

                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                      children: [
                        // ----------------------------------------
                        // EMERGENCY TYPE
                        // ----------------------------------------

                        Text(
                          'Emergency Type: '
                              '${receivedSosData!['type'] ?? 'Unknown'}',

                          style:
                          const TextStyle(
                            fontSize: 17,
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),

                        const SizedBox(
                          height: 10,
                        ),

                        // ----------------------------------------
                        // SOS ID
                        // ----------------------------------------

                        Text(
                          'SOS ID: '
                              '${receivedSosData!['sosId'] ?? '-'}',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        // ----------------------------------------
                        // LATITUDE
                        // ----------------------------------------

                        Text(
                          'Latitude: '
                              '${receivedSosData!['latitude'] ?? '-'}',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        // ----------------------------------------
                        // LONGITUDE
                        // ----------------------------------------

                        Text(
                          'Longitude: '
                              '${receivedSosData!['longitude'] ?? '-'}',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        // ----------------------------------------
                        // NETWORK
                        // ----------------------------------------

                        Text(
                          'Network: '
                              '${receivedSosData!['network'] ?? '-'}',
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        // ========================================
                        // RECEIVING VOICE
                        // ========================================

                        if (_receivingVoice)
                          Container(
                            width:
                            double.infinity,

                            padding:
                            const EdgeInsets
                                .all(14),

                            decoration:
                            BoxDecoration(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                12,
                              ),

                              border:
                              Border.all(
                                color:
                                Colors.orange,
                              ),
                            ),

                            child: const Row(
                              children: [
                                Icon(
                                  Icons.mic,
                                  color:
                                  Colors.orange,
                                ),

                                SizedBox(
                                  width: 10,
                                ),

                                Expanded(
                                  child: Text(
                                    'Receiving voice message...',
                                    style:
                                    TextStyle(
                                      fontWeight:
                                      FontWeight
                                          .bold,
                                    ),
                                  ),
                                ),

                                SizedBox(
                                  width: 20,
                                  height: 20,

                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth:
                                    2,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ========================================
                        // VOICE RECEIVED
                        // ========================================

                        if (!_receivingVoice &&
                            receivedVoicePath !=
                                null)
                          Container(
                            width:
                            double.infinity,

                            padding:
                            const EdgeInsets
                                .all(14),

                            decoration:
                            BoxDecoration(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                12,
                              ),

                              border:
                              Border.all(
                                color:
                                Colors.green,
                              ),
                            ),

                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.mic,
                                      color:
                                      Colors.green,
                                    ),

                                    SizedBox(
                                      width: 10,
                                    ),

                                    Expanded(
                                      child:
                                      Text(
                                        'Voice Message Received',
                                        style:
                                        TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(
                                  height: 12,
                                ),

                                SizedBox(
                                  width:
                                  double.infinity,

                                  height: 50,

                                  child:
                                  ElevatedButton
                                      .icon(
                                    onPressed:
                                    playReceivedVoice,

                                    icon:
                                    const Icon(
                                      Icons
                                          .play_arrow,
                                    ),

                                    label:
                                    const Text(
                                      'Play Received Voice',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ========================================
                        // VOICE ATTACHED BUT NOT YET RECEIVED
                        // ========================================

                        if (!_receivingVoice &&
                            receivedVoicePath ==
                                null &&
                            receivedSosData![
                            'voiceAttached'] ==
                                true)
                          Container(
                            width:
                            double.infinity,

                            padding:
                            const EdgeInsets
                                .all(14),

                            decoration:
                            BoxDecoration(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                12,
                              ),

                              border:
                              Border.all(
                                color:
                                Colors.orange,
                              ),
                            ),

                            child: const Row(
                              children: [
                                Icon(
                                  Icons
                                      .hourglass_empty,
                                  color:
                                  Colors.orange,
                                ),

                                SizedBox(
                                  width: 10,
                                ),

                                Expanded(
                                  child: Text(
                                    'Voice message is being received...',
                                    style:
                                    TextStyle(
                                      fontWeight:
                                      FontWeight
                                          .bold,
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