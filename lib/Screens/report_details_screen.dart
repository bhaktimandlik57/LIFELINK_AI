
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  double? latitude;
  double? longitude;

  late String currentDescription;
  late String currentSeverity;
  late String currentDisaster;
  String currentStatus = 'Waiting for response';
  bool isLoading = true;

  final List<String> disasterTypes = [
    'Flood',
    'Earthquake',
    'Landslide',
    'Cyclone',
    'Fire',
    'Other',
  ];

  final List<String> severityLevels = [
    'Low',
    'Medium',
    'High',
  ];

  @override
  void initState() {
    super.initState();

    currentDescription = widget.description;
    currentSeverity = widget.severity;
    currentDisaster = widget.disaster;

    loadReport();
  }

  Future<void> loadReport() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedReport = prefs.getString('latest_report');

      if (savedReport != null) {
        final Map<String, dynamic> report =
        jsonDecode(savedReport);

        // Only use saved details when they belong to this report.
        final savedId = report['reportId']?.toString();
        final isSameReport = widget.reportId == 'Not available' ||
            savedId == widget.reportId;

        if (isSameReport) {
          currentDescription =
              (report['description'] ?? currentDescription).toString();
          currentSeverity =
              (report['severity'] ?? currentSeverity).toString();
          currentDisaster =
              (report['disaster'] ??
                  report['disasterType'] ??
                  currentDisaster)
                  .toString();

          latitude = (report['latitude'] as num?)?.toDouble();
          longitude = (report['longitude'] as num?)?.toDouble();

          currentStatus =
              (report['status'] ?? currentStatus).toString();
        }
      }
    } catch (e) {
      debugPrint('Error loading report: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color severityColor() {
    switch (currentSeverity) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  bool get isResolved => currentStatus == 'Resolved';

  String locationText() {
    if (latitude == null || longitude == null) {
      return 'Location not available';
    }

    return '${latitude!.toStringAsFixed(6)}, '
        '${longitude!.toStringAsFixed(6)}';
  }

  Future<void> saveReport({
    required String description,
    required String severity,
    required String disaster,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedReport = prefs.getString('latest_report');

    Map<String, dynamic> report = {};

    if (savedReport != null) {
      try {
        report = Map<String, dynamic>.from(
          jsonDecode(savedReport) as Map,
        );
      } catch (e) {
        debugPrint('Could not read previous report: $e');
      }
    }

    // Do not overwrite a different report with this screen's details.
    final savedId = report['reportId']?.toString();
    final isSameReport = report.isEmpty ||
        widget.reportId == 'Not available' ||
        savedId == widget.reportId;

    if (!isSameReport) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This report is not the latest saved report. '
                  'The screen was not saved.',
            ),
          ),
        );
      }
      return;
    }

    report['reportId'] = widget.reportId;
    report['description'] = description;
    report['severity'] = severity;
    report['disaster'] = disaster;
    report['status'] = status;

    if (latitude != null) {
      report['latitude'] = latitude;
    }
    if (longitude != null) {
      report['longitude'] = longitude;
    }

    await prefs.setString('latest_report', jsonEncode(report));

    if (!mounted) return;

    setState(() {
      currentDescription = description;
      currentSeverity = severity;
      currentDisaster = disaster;
      currentStatus = status;
    });
  }

  Future<void> updateReport() async {
    final descriptionController =
    TextEditingController(text: currentDescription);

    String selectedDisaster = currentDisaster;
    String selectedSeverity = currentSeverity;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Disaster Type'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: disasterTypes.contains(selectedDisaster)
                          ? selectedDisaster
                          : 'Other',
                      isExpanded: true,
                      items: disasterTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedDisaster = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Severity'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: severityLevels.contains(selectedSeverity)
                          ? selectedSeverity
                          : 'Medium',
                      isExpanded: true,
                      items: severityLevels.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedSeverity = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('Description'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Describe the disaster...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      await saveReport(
        description: descriptionController.text.trim(),
        severity: selectedSeverity,
        disaster: selectedDisaster,
        status: currentStatus,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report updated successfully!'),
          ),
        );
      }
    }

    descriptionController.dispose();
  }

  Future<void> markAsResolved() async {
    if (isResolved) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resolve Report?'),
        content: const Text(
          'Are you sure this disaster report has been resolved?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes, Resolve'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await saveReport(
      description: currentDescription,
      severity: currentSeverity,
      disaster: currentDisaster,
      status: 'Resolved',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report marked as resolved!'),
      ),
    );
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isResolved
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isResolved
                        ? Icons.check_circle
                        : Icons.circle,
                    size: 10,
                    color: isResolved ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isResolved ? 'RESOLVED' : 'ACTIVE REPORT',
                    style: TextStyle(
                      color: isResolved ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '$currentDisaster Report',
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Report ID: ${widget.reportId}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            _infoCard(
              Icons.location_on,
              'GPS Location',
              locationText(),
              valueColor:
              latitude != null ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 12),
            _infoCard(
              Icons.access_time,
              'Reported',
              'Report details',
            ),
            const SizedBox(height: 12),
            _infoCard(
              Icons.warning_amber_rounded,
              'Severity',
              currentSeverity,
              valueColor: severityColor(),
            ),
            const SizedBox(height: 25),
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
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                currentDescription.isEmpty
                    ? 'No description provided.'
                    : currentDescription,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rescue Status',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isResolved
                            ? Icons.check_circle
                            : Icons.radio_button_checked,
                        color: isResolved
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          currentStatus,
                          style: const TextStyle(fontSize: 15),
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
              height: 52,
              child: ElevatedButton(
                onPressed: updateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: isResolved ? null : markAsResolved,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isResolved ? 'Report Resolved ✓' : 'Mark as Resolved',
                  style: const TextStyle(
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
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.red, size: 25),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontWeight: FontWeight.w600,
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
