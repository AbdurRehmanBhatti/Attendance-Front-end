import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import 'crashlytics_service.dart';

class InAppUpdateService {
  static bool _hasCheckedThisSession = false;

  Future<void> checkAndTriggerUpdateIfAvailable() async {
    if (_hasCheckedThisSession) {
      return;
    }

    _hasCheckedThisSession = true;

    if (!kReleaseMode || !Platform.isAndroid) {
      return;
    }

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }

      final shouldForceImmediate =
          info.immediateUpdateAllowed && info.updatePriority >= 4;

      if (shouldForceImmediate) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }

      if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (error, stackTrace) {
      await CrashlyticsService.recordHandledError(
        error,
        stackTrace,
        reason:
            'InAppUpdateService.checkAndTriggerUpdateIfAvailable: update check failed',
      );
    }
  }
}
