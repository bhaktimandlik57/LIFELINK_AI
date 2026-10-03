import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:torch_light/torch_light.dart';

class ReportDetailsScreen extends StatefulWidget {
  final String description;
  final String severity;
  final String disaster;
  final String reportId;

  const ReportDetailsScreen({
    super.key,
    required this.description,
    this.severity = 'Medium',
    this.disaster = 'Flood',
    this.reportId = 'Not available',
  });

  @override
  State<ReportDetailsScreen> createState() =>
      _ReportDetailsScreenState();
}

class _ReportDetailsScreenState
    extends State<ReportDetailsScreen> {

  double? latitude;
  double? longitude;

  @override
  void initState() {
    super.initState();
    loadLocation();
  }

  Future<void> loadLocation() async {
    final prefs = await SharedPreferences.getInstance();

    final savedReport = prefs.getString('latest_report');

    if (savedReport == null) return;

    try {
      final Map<String, dynamic> report =
      jsonDecode(savedReport);

      if (!mounted) return;

      setState(() {
        latitude = report['latitude'] != null
            ? (report['latitude'] as num).toDouble()
            : null;

        longitude = report['longitude'] != null
            ? (report['longitude'] as num).toDouble()
            : null;
      });
    } catch (e) {
      debugPrint('Error loading location: $e');
    }
  }

  Color _severityColor() {
    if (widget.severity == 'Low') {
      return Colors.green;
    } else if (widget.severity == 'Medium') {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String _locationText() {
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
        title: const Text(
          'Report Details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // ACTIVE REPORT
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),

              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),

              child: Row(
                mainAxisSize: MainAxisSize.min,

                children: [
                  Container(
                    width: 9,
                    height: 9,

                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Text(
                    'ACTIVE REPORT',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // DISASTER NAME
            Text(
              '${widget.disaster} Report',

              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // REPORT ID
            Text(
              'Report ID: ${widget.reportId}',

              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            // REAL GPS LOCATION
            _infoCard(
              Icons.location_on,
              'GPS Location',
              _locationText(),
              valueColor:
              latitude != null
                  ? Colors.blue
                  : Colors.grey,
            ),

            const SizedBox(height: 12),

            // REPORTED
            _infoCard(
              Icons.access_time,
              'Reported',
              'Just now',
            ),

            const SizedBox(height: 12),

            // SEVERITY
            _infoCard(
              Icons.warning_amber_rounded,
              'Severity',
              widget.severity,
              valueColor: _severityColor(),
            ),

            const SizedBox(height: 25),

            // DESCRIPTION
            const Text(
              'Description',

              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(15),

                border: Border.all(
                  color: Colors.grey.shade200,
                ),
              ),

              child: Text(
                widget.description.isEmpty
                    ? 'No description provided.'
                    : widget.description,

                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 25),

            // RESCUE STATUS
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.circular(15),
              ),

              child: const Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,

                children: [

                  Text(
                    'Rescue Status',

                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  SizedBox(height: 12),

                  Row(
                    children: [

                      Icon(
                        Icons.radio_button_checked,
                        color: Colors.orange,
                      ),

                      SizedBox(width: 10),

                      Text(
                        'Waiting for response',
                        style: TextStyle(
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // UPDATE BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,

              child: ElevatedButton(
                onPressed: () {},

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),

                child: const Text(
                  'Update Report',

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // RESOLVED BUTTON
            SizedBox(
              width: double.infinity,
              height: 52,

              child: OutlinedButton(
                onPressed: () {},

                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,

                  side: const BorderSide(
                    color: Colors.green,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                ),

                child: const Text(
                  'Mark as Resolved',

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(
      IconData icon,
      String title,
      String value, {
        Color? valueColor,
      }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(15),

        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),

      child: Row(
        children: [

          Icon(
            icon,
            color: Colors.red,
            size: 25,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(
                  title,

                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w600,
                    color: valueColor,
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