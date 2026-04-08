import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../models/user.dart';

class CrashlyticsService {
  CrashlyticsService._();

  static Future<void> setUserContext(User user) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(user.id.toString());
      await FirebaseCrashlytics.instance.setCustomKey('user_email', user.email);
      await FirebaseCrashlytics.instance.setCustomKey(
        'company_id',
        user.companyId ?? -1,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'company_name',
        user.companyName,
      );
      await FirebaseCrashlytics.instance.setCustomKey(
        'is_employee',
        user.isEmployee,
      );
      await FirebaseCrashlytics.instance.setCustomKey('is_admin', user.isAdmin);
    } catch (_) {}
  }

  static Future<void> clearUserContext() async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier('');
      await FirebaseCrashlytics.instance.setCustomKey('user_email', '');
      await FirebaseCrashlytics.instance.setCustomKey('company_id', -1);
      await FirebaseCrashlytics.instance.setCustomKey('company_name', '');
      await FirebaseCrashlytics.instance.setCustomKey('is_employee', false);
      await FirebaseCrashlytics.instance.setCustomKey('is_admin', false);
    } catch (_) {}
  }

  static Future<void> recordHandledError(
    Object error,
    StackTrace stackTrace, {
    required String reason,
    Map<String, Object?>? information,
  }) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        information:
            information?.entries.map(
              (entry) => '${entry.key}: ${entry.value}',
            ) ??
            const <Object>[],
        fatal: false,
      );
    } catch (_) {}
  }
}
