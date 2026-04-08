import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/account_deletion.dart';
import '../models/attendance.dart';
import '../models/attendance_history.dart';
import '../models/user.dart';
import 'auth_session_storage.dart';
import 'crashlytics_service.dart';

class ApiService {
  static const _timeout = Duration(seconds: 15);

  static final Map<String, String> _baseHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  static String? _authToken;
  static User? _currentUser;
  static Future<bool>? _refreshInFlight;

  static String? get authToken => _authToken;
  static User? get currentUser => _currentUser;
  static bool get isPasswordChangeRequired =>
      _currentUser?.requirePasswordChangeOnNextLogin ?? false;
  static bool get isAuthenticated =>
      _authToken != null && _authToken!.trim().isNotEmpty;

  static void restoreSession(User user) {
    _currentUser = user;
    _authToken = user.token;
    unawaited(CrashlyticsService.setUserContext(user));
  }

  static void clearSession() {
    _authToken = null;
    _currentUser = null;
    unawaited(CrashlyticsService.clearUserContext());
  }

  // POST /api/auth/login
  Future<User> login(String identifier, String password) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
    final response = await http
        .post(
          uri,
          headers: _baseHeaders,
          body: jsonEncode({'email': identifier.trim(), 'password': password}),
        )
        .timeout(_timeout);

    _throwIfRequestFailed(response);

    final user = User.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    restoreSession(user);
    return user;
  }

  // POST /api/auth/change-password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/change-password');
    await _sendAuthenticatedRequest(
      (headers) => http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              'currentPassword': currentPassword,
              'newPassword': newPassword,
            }),
          )
          .timeout(_timeout),
    );
  }

  // POST /api/auth/logout-all
  Future<void> logoutAll() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/logout-all');
    await _sendAuthenticatedRequest(
      (headers) => http.post(uri, headers: headers).timeout(_timeout),
    );
  }

  // POST /api/auth/forgot-password
  Future<String> forgotPassword(String email) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password');
    final response = await http
        .post(
          uri,
          headers: _baseHeaders,
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(_timeout);

    _throwIfRequestFailed(response);

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['message']?.toString();
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
    } catch (error, stackTrace) {
      unawaited(
        CrashlyticsService.recordHandledError(
          error,
          stackTrace,
          reason: 'ApiService.forgotPassword: response message parse failed',
        ),
      );
    }

    return 'If the email exists in our system, a password reset link has been generated.';
  }

  // POST /api/auth/reset-password
  Future<void> resetPassword({
    required int userId,
    required String token,
    required String newPassword,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password');
    final response = await http
        .post(
          uri,
          headers: _baseHeaders,
          body: jsonEncode({
            'userId': userId,
            'token': token,
            'newPassword': newPassword,
          }),
        )
        .timeout(_timeout);

    _throwIfRequestFailed(response);
  }

  // POST /api/auth/refresh-token
  Future<RefreshTokenResponse> refreshToken() async {
    final user = _currentUser;
    if (user == null || user.refreshToken.trim().isEmpty) {
      throw UnauthorizedApiException(
        HttpStatus.unauthorized,
        'Session expired. Please sign in again.',
      );
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/refresh-token');
    final request = RefreshTokenRequest(refreshToken: user.refreshToken);

    final response = await http
        .post(uri, headers: _baseHeaders, body: jsonEncode(request.toJson()))
        .timeout(_timeout);

    _throwIfRequestFailed(response);

    final refreshed = RefreshTokenResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );

    final updatedUser = user.copyWith(
      token: refreshed.token,
      accessTokenExpiresAtUtc: refreshed.accessTokenExpiresAtUtc,
      refreshToken: refreshed.refreshToken,
      refreshTokenExpiresAtUtc: refreshed.refreshTokenExpiresAtUtc,
    );

    restoreSession(updatedUser);
    await AuthSessionStorage.saveUser(updatedUser);
    return refreshed;
  }

  // POST /api/attendance/in
  Future<Attendance> clockIn({double? latitude, double? longitude}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/in');
    final response = await _sendAuthenticatedRequest(
      (headers) => http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(_gpsPayload(latitude, longitude)),
          )
          .timeout(_timeout),
    );

    return Attendance.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // POST /api/attendance/out
  Future<Attendance> clockOut({double? latitude, double? longitude}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/out');
    final response = await _sendAuthenticatedRequest(
      (headers) => http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(_gpsPayload(latitude, longitude)),
          )
          .timeout(_timeout),
    );

    return Attendance.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // GET /api/attendance/history?startDateUtc=...&endDateUtc=...
  Future<AttendanceHistoryResponse> getAttendanceHistory({
    required DateTime startUtc,
    required DateTime endUtc,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/history')
        .replace(
          queryParameters: {
            'startDateUtc': startUtc.toUtc().toIso8601String(),
            'endDateUtc': endUtc.toUtc().toIso8601String(),
          },
        );

    final response = await _sendAuthenticatedRequest(
      (headers) => http.get(uri, headers: headers).timeout(_timeout),
    );

    return AttendanceHistoryResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // GET /api/attendance/summary
  Future<AttendanceSummaryTotals> getAttendanceSummary() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/summary');
    final response = await _sendAuthenticatedRequest(
      (headers) => http.get(uri, headers: headers).timeout(_timeout),
    );

    return AttendanceSummaryTotals.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // GET /api/attendance/today
  Future<List<Attendance>> getTodayAttendance() async {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final response = await getAttendanceHistory(startUtc: start, endUtc: end);
    return response.records;
  }

  // POST /api/account-deletion/request-authenticated
  Future<AccountDeletionRequestResponse> requestAuthenticatedAccountDeletion({
    String? reason,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/account-deletion/request-authenticated',
    );

    final response = await _sendAuthenticatedRequest(
      (headers) => http
          .post(
            uri,
            headers: headers,
            body: jsonEncode({
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
            }),
          )
          .timeout(_timeout),
    );

    return AccountDeletionRequestResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // GET /api/account-deletion/my-request-status
  Future<AccountDeletionMyRequestStatusResponse?>
  getMyAccountDeletionRequestStatus() async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/account-deletion/my-request-status',
    );

    try {
      final response = await _sendAuthenticatedRequest(
        (headers) => http.get(uri, headers: headers).timeout(_timeout),
      );

      return AccountDeletionMyRequestStatusResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on ApiException catch (error) {
      if (error.statusCode == HttpStatus.notFound) {
        return null;
      }
      rethrow;
    }
  }

  Map<String, String> _authHeaders() {
    if (!isAuthenticated) {
      throw UnauthorizedApiException(
        HttpStatus.unauthorized,
        'You are not logged in. Please sign in again.',
      );
    }

    return {
      ..._baseHeaders,
      HttpHeaders.authorizationHeader: 'Bearer $_authToken',
    };
  }

  Future<http.Response> _sendAuthenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var response = await send(_authHeaders());

    if (response.statusCode == HttpStatus.unauthorized) {
      final refreshed = await _attemptRefreshToken();
      if (!refreshed) {
        clearSession();
        throw UnauthorizedApiException(
          HttpStatus.unauthorized,
          'Session expired. Please sign in again.',
        );
      }

      response = await send(_authHeaders());
    }

    _throwIfRequestFailed(response);
    return response;
  }

  Future<bool> _attemptRefreshToken() async {
    final inFlightRefresh = _refreshInFlight;
    if (inFlightRefresh != null) {
      return inFlightRefresh;
    }

    final refreshFuture = _refreshTokenWithSingleFlight();
    _refreshInFlight = refreshFuture;

    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _refreshTokenWithSingleFlight() async {
    try {
      await refreshToken();
      return true;
    } on ApiException {
      clearSession();
      await AuthSessionStorage.clear();
      return false;
    } catch (error, stackTrace) {
      unawaited(
        CrashlyticsService.recordHandledError(
          error,
          stackTrace,
          reason:
              'ApiService._refreshTokenWithSingleFlight: unexpected refresh failure',
        ),
      );
      clearSession();
      await AuthSessionStorage.clear();
      return false;
    }
  }

  void _throwIfRequestFailed(http.Response response) {
    final parsed = _parseErrorPayload(response.body);

    if (response.statusCode == HttpStatus.forbidden &&
        parsed.code == 'password_change_required') {
      final user = _currentUser;
      if (user != null) {
        _currentUser = user.copyWith(requirePasswordChangeOnNextLogin: true);
      }

      throw PasswordChangeRequiredApiException(
        response.statusCode,
        parsed.message ?? 'Password change is required before continuing.',
        code: parsed.code,
        detail: parsed.detail,
        metadata: parsed.metadata,
      );
    }

    if (response.statusCode == HttpStatus.unauthorized) {
      clearSession();
      throw UnauthorizedApiException(
        response.statusCode,
        parsed.message ?? 'Session expired. Please sign in again.',
      );
    }

    if (response.statusCode != HttpStatus.ok) {
      throw ApiException(
        response.statusCode,
        parsed.message ?? 'Request failed.',
        code: parsed.code,
        detail: parsed.detail,
        metadata: parsed.metadata,
      );
    }
  }

  Map<String, dynamic> _gpsPayload(double? latitude, double? longitude) {
    if (latitude == null && longitude == null) {
      return {};
    }

    return {'latitude': latitude, 'longitude': longitude};
  }

  _ParsedApiError _parseErrorPayload(
    String body, {
    String fallback = 'Request failed.',
  }) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        final validationErrors = json['errors'];
        if (validationErrors is Map<String, dynamic> &&
            validationErrors.isNotEmpty) {
          final messages = <String>[];
          for (final value in validationErrors.values) {
            if (value is List) {
              messages.addAll(value.map((e) => e.toString()));
            }
          }
          if (messages.isNotEmpty) {
            return _ParsedApiError(
              message: messages.join(' '),
              code: json['code']?.toString(),
              detail: json['detail']?.toString(),
              metadata: _toStringMap(json['metadata']),
            );
          }
        }

        final message =
            (json['message'] ??
                    json['detail'] ??
                    json['error'] ??
                    json['title'] ??
                    fallback)
                .toString();

        return _ParsedApiError(
          message: message,
          code: json['code']?.toString(),
          detail: json['detail']?.toString(),
          metadata: _toStringMap(json['metadata']),
        );
      }
    } catch (error, stackTrace) {
      unawaited(
        CrashlyticsService.recordHandledError(
          error,
          stackTrace,
          reason:
              'ApiService._parseErrorPayload: failed to decode API error payload',
        ),
      );
    }

    if (body.trim().isEmpty) {
      return _ParsedApiError(message: fallback);
    }

    return _ParsedApiError(message: body);
  }

  Map<String, dynamic>? _toStringMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    return null;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;
  final String? detail;
  final Map<String, dynamic>? metadata;

  ApiException(
    this.statusCode,
    this.message, {
    this.code,
    this.detail,
    this.metadata,
  });

  @override
  String toString() =>
      'ApiException($statusCode, code: $code, detail: $detail): $message';
}

class UnauthorizedApiException extends ApiException {
  UnauthorizedApiException(super.statusCode, super.message);
}

class PasswordChangeRequiredApiException extends ApiException {
  PasswordChangeRequiredApiException(
    super.statusCode,
    super.message, {
    super.code,
    super.detail,
    super.metadata,
  });
}

class _ParsedApiError {
  final String? message;
  final String? code;
  final String? detail;
  final Map<String, dynamic>? metadata;

  _ParsedApiError({this.message, this.code, this.detail, this.metadata});
}

class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() {
    return {'refreshToken': refreshToken};
  }
}

class RefreshTokenResponse {
  final String token;
  final DateTime accessTokenExpiresAtUtc;
  final String refreshToken;
  final DateTime refreshTokenExpiresAtUtc;

  const RefreshTokenResponse({
    required this.token,
    required this.accessTokenExpiresAtUtc,
    required this.refreshToken,
    required this.refreshTokenExpiresAtUtc,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      token: (json['token'] as String?) ?? '',
      accessTokenExpiresAtUtc: DateTime.parse(
        (json['accessTokenExpiresAtUtc'] as String?) ?? '',
      ).toUtc(),
      refreshToken: (json['refreshToken'] as String?) ?? '',
      refreshTokenExpiresAtUtc: DateTime.parse(
        (json['refreshTokenExpiresAtUtc'] as String?) ?? '',
      ).toUtc(),
    );
  }
}
