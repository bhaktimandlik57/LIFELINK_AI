import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() => _LiveLocationScreenState();
}

class _LiveLocationScreenState extends State<LiveLocationScreen> {
  Position? position;
  StreamSubscription<Position>? positionSubscription;

  String status = 'Getting your location...';

  @override
  void initState() {
    super.initState();
    startLocation();
  }

  Future<void> startLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() {
        status = 'Please turn ON Location/GPS.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        status = 'Location permission denied.';
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        status = 'Location permission permanently denied.';
      });
      return;
    }

    try {
      Position currentPosition =
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        position = currentPosition;
        status = 'Live location active';
      });

      positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((Position newPosition) {
        if (!mounted) return;

        setState(() {
          position = newPosition;
        });
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        status = 'Unable to get location.';
      });
    }
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Live Location',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: Colors.green,
                size: 65,
              ),
            ),

            const SizedBox(height: 25),

            Text(
              status,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: position != null
                    ? Colors.green
                    : Colors.orange,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            if (position != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    _locationRow(
                      'Latitude',
                      position!.latitude.toStringAsFixed(6),
                    ),
                    const Divider(height: 25),
                    _locationRow(
                      'Longitude',
                      position!.longitude.toStringAsFixed(6),
                    ),
                    const Divider(height: 25),
                    _locationRow(
                      'Accuracy',
                      '${position!.accuracy.toStringAsFixed(1)} m',
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 25),

            const Text(
              'This is the real GPS position of this device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationRow(String title, String value) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}