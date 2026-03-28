import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class ClockLocationResult {
  final double? latitude;
  final double? longitude;
  final String? warning;

  const ClockLocationResult({this.latitude, this.longitude, this.warning});

  bool get hasCoordinates => latitude != null && longitude != null;
}

class LocationService {
  static const Duration _locationTimeout = Duration(seconds: 12);

  Future<ClockLocationResult> getClockLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const ClockLocationResult(
        warning: 'Location is disabled. Continuing without GPS.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const ClockLocationResult(
        warning: 'Location permission denied. Continuing without GPS.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const ClockLocationResult(
        warning:
            'Location permission is permanently denied. Continuing without GPS.',
      );
    }

    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return ClockLocationResult(
          latitude: lastKnown.latitude,
          longitude: lastKnown.longitude,
        );
      }
    } catch (e) {
      debugPrint('LocationService.getLastKnownPosition failed: $e');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _locationTimeout,
        ),
      );

      return ClockLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      return const ClockLocationResult(
        warning: 'Location timed out. Continuing without GPS.',
      );
    } on PermissionDeniedException {
      return const ClockLocationResult(
        warning: 'Location permission denied. Continuing without GPS.',
      );
    } on LocationServiceDisabledException {
      return const ClockLocationResult(
        warning: 'Location is disabled. Continuing without GPS.',
      );
    } catch (_) {
      return const ClockLocationResult(
        warning: 'Unable to read location. Continuing without GPS.',
      );
    }
  }
}
