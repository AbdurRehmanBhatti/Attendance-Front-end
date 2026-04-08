import 'package:attendance_app/models/account_deletion.dart';
import 'package:attendance_app/screens/delete_account_screen.dart';
import 'package:attendance_app/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApiService extends ApiService {
  String? receivedReason;
  int callCount = 0;

  @override
  Future<SelfDeleteAccountResponse> deleteMyAccount({String? reason}) async {
    callCount += 1;
    receivedReason = reason;

    return SelfDeleteAccountResponse(
      forceLogout: true,
      deletedAtUtc: DateTime.utc(2026, 4, 7, 12, 0),
      status: 'Deleted',
      message: 'Deleted successfully',
    );
  }
}

class _FakeUnauthorizedApiService extends ApiService {
  int callCount = 0;

  @override
  Future<SelfDeleteAccountResponse> deleteMyAccount({String? reason}) async {
    callCount += 1;
    throw UnauthorizedApiException(401, 'Session expired. Please sign in again.');
  }
}

void main() {
  testWidgets(
    'delete account success clears session and resets to login route',
    (tester) async {
      final api = _FakeApiService();
      var didClearSession = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DeleteAccountScreen(
            apiService: api,
            clearSession: () async {
              didClearSession = true;
            },
            navigateToLogin: (context) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('Login Placeholder', key: Key('login-page')),
                  ),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'No longer needed');

      await tester.tap(find.text('Delete Account Now'));
      await tester.pumpAndSettle();

      expect(find.text('Delete your account?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete Account'));
      await tester.pumpAndSettle();

      expect(api.callCount, 1);
      expect(api.receivedReason, 'No longer needed');
      expect(didClearSession, isTrue);
      expect(find.byKey(const Key('login-page')), findsOneWidget);

      final navigatorState = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      expect(navigatorState.canPop(), isFalse);
    },
  );

  testWidgets(
    'delete account unauthorized clears session and resets to login route',
    (tester) async {
      final api = _FakeUnauthorizedApiService();
      var didClearSession = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DeleteAccountScreen(
            apiService: api,
            clearSession: () async {
              didClearSession = true;
            },
            navigateToLogin: (context) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(
                    body: Text('Login Placeholder', key: Key('login-page')),
                  ),
                ),
                (route) => false,
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Delete Account Now'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete Account'));
      await tester.pumpAndSettle();

      expect(api.callCount, 1);
      expect(didClearSession, isTrue);
      expect(find.byKey(const Key('login-page')), findsOneWidget);

      final navigatorState = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      expect(navigatorState.canPop(), isFalse);
    },
  );
}
