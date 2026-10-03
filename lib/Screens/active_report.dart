import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'report_details_screen.dart';

class ActiveReportsScreen extends StatefulWidget {
  const ActiveReportsScreen({super.key});

  @override
  State<ActiveReportsScreen> createState() =>
      _ActiveReportsScreenState();
}

class _ActiveReportsScreenState
    extends State<ActiveReportsScreen> {
  String description = 'No description provided.';
  String severity = 'Medium';
  String disaster = 'Flood';
  String reportId = 'Not available';

  double? latitude;
  double? longitude;

  String? photoPath;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    final prefs = await SharedPreferences.getInstance();

    final savedReport = prefs.getString('latest_report');

    if (savedReport == null) {
      return;
    }

    try {
      final Map<String, dynamic> report =
      jsonDecode(savedReport);

      if (!mounted) return;

      setState(() {
        description =
            report['description']?.toString() ??
                'No description provided.';

        severity =
            report['severity']?.toString() ??
                'Medium';

        disaster =
            report['disaster']?.toString() ??
                'Flood';

        reportId =
            report['reportId']?.toString() ??
                'Not available';

        // REAL GPS coordinates
        latitude = report['latitude'] != null
            ? (report['latitude'] as num).toDouble()
            : null;

        longitude = report['longitude'] != null
            ? (report['longitude'] as num).toDouble()
            : null;

        // SAVED PHOTO PATH
        photoPath = report['photoPath']?.toString();
      });
    } catch (e) {
      debugPrint('Error loading report: $e');
    }
  }

  Color severityColor() {
    if (severity == 'Low') {
      return Colors.green;
    }

    if (severity == 'High') {
      return Colors.red;
    }

    return Colors.orange;
  }

  String locationText() {
    if (latitude == null || longitude == null) {
      return 'Location not available';
    }

    return '${latitude!.toStringAsFixed(6)}, '
        '${longitude!.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,

        title: const Text(
          'Active Reports',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,

            children: [
              const Text(
                'Your Reports',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Track the status of your submitted disaster reports.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ReportDetailsScreen(
                            description: description,
                            severity: severity,
                            disaster: disaster,
                            reportId: reportId,
                          ),
                    ),
                  );
                },

                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                    BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade200,
                    ),
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      // ACTIVE STATUS
                      Row(
                        children: [
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),

                            decoration: BoxDecoration(
                              color: Colors.red
                                  .withValues(alpha: 0.1),

                              borderRadius:
                              BorderRadius.circular(20),
                            ),

                            child: const Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  color: Colors.red,
                                  size: 8,
                                ),

                                SizedBox(width: 6),

                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 15,
                            color: Colors.grey,
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // DISASTER INFORMATION
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            backgroundColor:
                            Color(0xFFFFF3E0),

                            child: Icon(
                              Icons.water,
                              color: Colors.orange,
                              size: 27,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,

                              children: [
                                Text(
                                  '$disaster Report',
                                  style:
                                  const TextStyle(
                                    fontSize: 17,
                                    fontWeight:
                                    FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Report ID: $reportId',
                                  style:
                                  const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      const Divider(),

                      const SizedBox(height: 10),

                      // DESCRIPTION
                      const Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        description,
                        maxLines: 3,
                        overflow:
                        TextOverflow.ellipsis,

                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ATTACHED PHOTO
                      if (photoPath != null &&
                          photoPath!.isNotEmpty &&
                          File(photoPath!).existsSync()) ...[
                        const Text(
                          'Attached Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        ClipRRect(
                          borderRadius:
                          BorderRadius.circular(12),

                          child: Image.file(
                            File(photoPath!),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(height: 14),
                      ],

                      // SEVERITY
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 19,
                            color: severityColor(),
                          ),

                          const SizedBox(width: 6),

                          const Text(
                            'Severity: ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),

                          Text(
                            severity,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                              FontWeight.bold,
                              color:
                              severityColor(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // REAL GPS LOCATION
                      Container(
                        width: double.infinity,
                        padding:
                        const EdgeInsets.all(12),

                        decoration: BoxDecoration(
                          color: Colors.red
                              .withValues(alpha: 0.05),

                          borderRadius:
                          BorderRadius.circular(10),

                          border: Border.all(
                            color: Colors.red
                                .withValues(alpha: 0.15),
                          ),
                        ),

                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,

                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 20,
                              color: Colors.red,
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,

                                children: [
                                  const Text(
                                    'Live GPS Location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    locationText(),
                                    style:
                                    const TextStyle(
                                      fontSize: 13,
                                      color:
                                      Colors.blue,
                                      fontWeight:
                                      FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // COPY GPS
                            if (latitude != null &&
                                longitude != null)
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  size: 18,
                                  color: Colors.grey,
                                ),

                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text:
                                      locationText(),
                                    ),
                                  );

                                  ScaffoldMessenger
                                      .of(context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'GPS coordinates copied.',
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // INFORMATION BOX
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: Colors.blue
                      .withValues(alpha: 0.08),

                  borderRadius:
                  BorderRadius.circular(15),

                  border: Border.all(
                    color: Colors.blue
                        .withValues(alpha: 0.15),
                  ),
                ),

                child: const Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue,
                    ),

                    SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Tap an active report to view complete report details and rescue status.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          height: 1.4,
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
    );
  }
}