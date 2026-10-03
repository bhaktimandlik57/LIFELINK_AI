import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'report_data.dart';

class ReportDisasterScreen extends StatefulWidget {
  const ReportDisasterScreen({super.key});

  @override
  State<ReportDisasterScreen> createState() =>
      _ReportDisasterScreenState();
}

class _ReportDisasterScreenState
    extends State<ReportDisasterScreen> {
  String selectedDisaster = 'Flood';
  String selectedSeverity = 'Medium';

  final TextEditingController descriptionController =
  TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? selectedImage;

  bool isGettingLocation = false;
  bool reportSubmitted = false;

  String reportId = '';

  double? reportLatitude;
  double? reportLongitude;

  final List<String> disasters = [
    'Flood',
    'Earthquake',
    'Landslide',
    'Cyclone',
    'Fire',
    'Other',
  ];

  @override
  void dispose() {
    descriptionController.dispose();
    super.dispose();
  }

  // ============================================================
  // TAKE PHOTO
  // ============================================================

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open camera: $e'),
        ),
      );
    }
  }

  // ============================================================
  // SUBMIT REPORT
  // ============================================================

  Future<void> submitReport() async {
    if (descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please describe the disaster first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isGettingLocation = true;
    });

    try {
      // Check GPS
      final bool serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          isGettingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please turn ON Location/GPS.',
            ),
          ),
        );

        return;
      }

      // Check permission
      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
        await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          isGettingLocation = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required.',
            ),
          ),
        );

        return;
      }

      // Get current GPS position
      final Position position =
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Save coordinates
      reportLatitude = position.latitude;
      reportLongitude = position.longitude;

      // Save latest description if your report_data.dart supports it
      latestReportDescription =
          descriptionController.text.trim();

      // Generate report ID
      reportId =
      'LL-${DateTime.now().millisecondsSinceEpoch}';

      // Save report locally
      final SharedPreferences prefs =
      await SharedPreferences.getInstance();

      final Map<String, dynamic> report = {
        'reportId': reportId,
        'disaster': selectedDisaster,
        'description':
        descriptionController.text.trim(),
        'severity': selectedSeverity,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': 'GPS Location Attached',
        'status': 'PENDING',
        'network': 'Waiting for network',
        'photoPath': selectedImage?.path,
      };

      await prefs.setString(
        'latest_report',
        jsonEncode(report),
      );

      if (!mounted) return;

      setState(() {
        isGettingLocation = false;
        reportSubmitted = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isGettingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not submit report: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SEVERITY COLOR
  // ============================================================

  Color severityColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green;

      case 'High':
        return Colors.red;

      default:
        return Colors.orange;
    }
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (reportSubmitted) {
      return _buildSubmittedScreen();
    }

    return _buildReportForm();
  }

  // ============================================================
  // REPORT FORM
  // ============================================================

  Widget _buildReportForm() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Disaster'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Text(
                'Report a Disaster',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Provide information about the emergency.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Disaster Type',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: selectedDisaster,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                items: disasters.map(
                      (String disaster) {
                    return DropdownMenuItem<String>(
                      value: disaster,
                      child: Text(disaster),
                    );
                  },
                ).toList(),
                onChanged: isGettingLocation
                    ? null
                    : (String? value) {
                  if (value == null) return;

                  setState(() {
                    selectedDisaster = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              const Text(
                'Describe the Situation',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: descriptionController,
                maxLines: 5,
                enabled: !isGettingLocation,
                decoration: InputDecoration(
                  hintText:
                  'Example: Water level is rising near the road...',
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Report Severity',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: _severityButton(
                      'Low',
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _severityButton(
                      'Medium',
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _severityButton(
                      'High',
                      Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // LOCATION
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Location',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Current GPS location will be attached when you submit.',
                  ),
                  trailing: const Icon(
                    Icons.gps_fixed,
                    color: Colors.green,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // PHOTO BUTTON
              // ==================================================

              InkWell(
                onTap: isGettingLocation
                    ? null
                    : pickImage,
                borderRadius:
                BorderRadius.circular(12),
                child: Card(
                  child: Padding(
                    padding:
                    const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.blue
                                .withOpacity(0.1),
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                          child: Icon(
                            selectedImage == null
                                ? Icons.camera_alt
                                : Icons.check_circle,
                            color: selectedImage == null
                                ? Colors.blue
                                : Colors.green,
                          ),
                        ),

                        const SizedBox(width: 15),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add Photo',
                                style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                selectedImage == null
                                    ? 'Optional - take a photo'
                                    : 'Photo attached',
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Icon(
                          selectedImage == null
                              ? Icons.chevron_right
                              : Icons.check,
                          color: selectedImage == null
                              ? Colors.grey
                              : Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ==================================================
              // PHOTO PREVIEW
              // ==================================================

              if (selectedImage != null) ...[
                const SizedBox(height: 10),

                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(12),
                  child: Image.file(
                    File(selectedImage!.path),
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (context, error, stackTrace) {
                      return Container(
                        height: 220,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isGettingLocation
                        ? null
                        : pickImage,
                    icon:
                    const Icon(Icons.camera_alt),
                    label:
                    const Text('Retake Photo'),
                  ),
                ),
              ],

              const SizedBox(height: 25),

              // ==================================================
              // SUBMIT
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: isGettingLocation
                      ? null
                      : submitReport,
                  icon: isGettingLocation
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.send),
                  label: Text(
                    isGettingLocation
                        ? 'Getting Location...'
                        : 'Submit Report',
                    style: const TextStyle(
                      fontSize: 16,
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

  // ============================================================
  // SEVERITY BUTTON
  // ============================================================

  Widget _severityButton(
      String title,
      Color color,
      ) {
    final bool selected =
        selectedSeverity == title;

    return GestureDetector(
      onTap: isGettingLocation
          ? null
          : () {
        setState(() {
          selectedSeverity = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : Colors.white,
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color:
            selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.circle,
              color: color,
              size: 14,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color:
                selected ? color : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUBMITTED SCREEN
  // ============================================================

  Widget _buildSubmittedScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Submitted'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 25),

              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 55,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Report Submitted',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Your disaster report has been saved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              // PHOTO
              if (selectedImage != null)
                ClipRRect(
                  borderRadius:
                  BorderRadius.circular(15),
                  child: Image.file(
                    File(selectedImage!.path),
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),

              const SizedBox(height: 20),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _infoRow(
                        'Report ID',
                        reportId,
                      ),

                      const Divider(height: 25),

                      _infoRow(
                        'Disaster',
                        selectedDisaster,
                      ),

                      const SizedBox(height: 12),

                      _infoRow(
                        'Severity',
                        selectedSeverity,
                        color: severityColor(
                          selectedSeverity,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _infoRow(
                        'Latitude',
                        reportLatitude == null
                            ? 'Unavailable'
                            : reportLatitude!
                            .toStringAsFixed(6),
                      ),

                      const SizedBox(height: 12),

                      _infoRow(
                        'Longitude',
                        reportLongitude == null
                            ? 'Unavailable'
                            : reportLongitude!
                            .toStringAsFixed(6),
                      ),

                      const SizedBox(height: 12),

                      _infoRow(
                        'GPS',
                        'Attached',
                        color: Colors.green,
                      ),

                      const SizedBox(height: 12),

                      _infoRow(
                        'Photo',
                        selectedImage == null
                            ? 'Not attached'
                            : 'Attached',
                        color: selectedImage == null
                            ? Colors.grey
                            : Colors.green,
                      ),

                      const SizedBox(height: 12),

                      _infoRow(
                        'Status',
                        'PENDING',
                        color: Colors.orange,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius:
                  BorderRadius.circular(12),
                ),
                child: const Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Relay',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The report is stored locally and can be synchronized when connectivity is available.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.home),
                  label:
                  const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _infoRow(
      String title,
      String value, {
        Color? color,
      }) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}