
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LiveLocationScreen extends StatefulWidget {
  const LiveLocationScreen({super.key});

  @override
  State<LiveLocationScreen> createState() =>
      _LiveLocationScreenState();
}

class _LiveLocationScreenState
    extends State<LiveLocationScreen> {
  Position? position;
  StreamSubscription<Position>? positionSubscription;

  final MapController mapController = MapController();

  bool mapReady = false;
  bool loading = false;
  String status = 'Getting your location...';

  @override
  void initState() {
    super.initState();
    startLocation();
  }

  Future<void> startLocation() async {
    if (loading) return;

    loading = true;

    if (mounted) {
      setState(() {
        status = 'Getting your location...';
      });
    }

    try {
      final serviceEnabled =
      await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            status = 'Please turn ON Location/GPS.';
          });
        }
        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            status =
            'Location permission denied. Please allow location access.';
          });
        }
        return;
      }

      final currentPosition =
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

      if (mapReady) {
        mapController.move(
          LatLng(
            currentPosition.latitude,
            currentPosition.longitude,
          ),
          16,
        );
      }

      await positionSubscription?.cancel();

      positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen(
            (newPosition) {
          if (!mounted) return;

          setState(() {
            position = newPosition;
            status = 'Live location active';
          });
        },
        onError: (error) {
          if (!mounted) return;

          setState(() {
            status = 'Location updates unavailable.';
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          status = position == null
              ? 'Unable to get location. Please try again.'
              : 'Showing last received GPS position.';
        });
      }
    } finally {
      loading = false;
      if (mounted) setState(() {});
    }
  }

  void centerOnLocation() {
    if (position == null || !mapReady) return;

    mapController.move(
      LatLng(
        position!.latitude,
        position!.longitude,
      ),
      16,
    );
  }

  @override
  void dispose() {
    positionSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPoint = position == null
        ? const LatLng(20.5937, 78.9629)
        : LatLng(
      position!.latitude,
      position!.longitude,
    );

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  position == null
                      ? Icons.location_searching
                      : Icons.gps_fixed,
                  color: position == null
                      ? Colors.orange
                      : Colors.green,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 340,
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: currentPoint,
                  initialZoom: position == null ? 5 : 16,
                  onMapReady: () {
                    mapReady = true;
                    if (position != null) {
                      centerOnLocation();
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                    'com.lifelinkai.app',
                  ),

                  if (position != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentPoint,
                          width: 60,
                          height: 60,
                          child: const Icon(
                            Icons.location_pin,
                            size: 48,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),

                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'OpenStreetMap contributors',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Map data © OpenStreetMap contributors. '
                'Internet is required to load map tiles.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          if (position != null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
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
                  const Divider(height: 24),
                  _locationRow(
                    'Longitude',
                    position!.longitude.toStringAsFixed(6),
                  ),
                  const Divider(height: 24),
                  _locationRow(
                    'Accuracy',
                    '${position!.accuracy.toStringAsFixed(1)} m',
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : startLocation,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh GPS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: position == null
                      ? null
                      : centerOnLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('My Location'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
