import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'crashlytics_service.dart';

class ClockLocationResult {
  final double? latitude;
  final double? longitude;
  final String? warning;
  final ClockLocationFailureReason? failureReason;

  const ClockLocationResult({
    this.latitude,
    this.longitude,
    this.warning,
    this.failureReason,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

enum ClockLocationFailureReason {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unavailable,
}

class LocationService {
  static const Duration _locationTimeout = Duration(seconds: 12);

  Future<ClockLocationResult> getClockLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const ClockLocationResult(
        warning:
            'Location service is off. Enable location to continue clock action.',
        failureReason: ClockLocationFailureReason.serviceDisabled,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return const ClockLocationResult(
        warning:
            'Location permission denied. Allow location to clock in or out.',
        failureReason: ClockLocationFailureReason.permissionDenied,
      );
    }

    if (permission == LocationPermission.deniedForever) {
      return const ClockLocationResult(
        warning:
            'Location permission is permanently denied. Enable it from app settings.',
        failureReason: ClockLocationFailureReason.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: _locationTimeout,
        ),
      );

      return ClockLocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return ClockLocationResult(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            warning:
                'Using your last known GPS location. If this looks wrong, retry.',
          );
        }
      } catch (error, stackTrace) {
        unawaited(
          CrashlyticsService.recordHandledError(
            error,
            stackTrace,
            reason:
                'LocationService.getClockLocation: lastKnownPosition timeout fallback failed',
          ),
        );
        debugPrint(
          'LocationService.getLastKnownPosition timeout fallback failed: $error',
        );
      }

      return const ClockLocationResult(
        warning: 'Location timed out. Please retry with a clear GPS signal.',
        failureReason: ClockLocationFailureReason.timeout,
      );
    } on PermissionDeniedException {
      return const ClockLocationResult(
        warning: 'Location permission denied. Allow location to continue.',
        failureReason: ClockLocationFailureReason.permissionDenied,
      );
    } on LocationServiceDisabledException {
      return const ClockLocationResult(
        warning: 'Location service is off. Enable location to continue.',
        failureReason: ClockLocationFailureReason.serviceDisabled,
      );
    } catch (error, stackTrace) {
      unawaited(
        CrashlyticsService.recordHandledError(
          error,
          stackTrace,
          reason:
              'LocationService.getClockLocation: unexpected location read error',
        ),
      );
      return const ClockLocationResult(
        warning: 'Unable to read location right now. Please retry.',
        failureReason: ClockLocationFailureReason.unavailable,
      );
    }
  }
}
