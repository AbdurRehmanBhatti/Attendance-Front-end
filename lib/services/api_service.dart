import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/attendance.dart';
import '../models/attendance_history.dart';
import '../models/user.dart';

class ApiService {
  static const _timeout = Duration(seconds: 15);

  static final Map<String, String> _baseHeaders = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  static String? _authToken;
  static User? _currentUser;

  static String? get authToken => _authToken;
  static User? get currentUser => _currentUser;
  static bool get isAuthenticated =>
      _authToken != null && _authToken!.trim().isNotEmpty;

  static void restoreSession(User user) {
    _currentUser = user;
    _authToken = user.token;
  }

  static void clearSession() {
    _authToken = null;
    _currentUser = null;
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

  // POST /api/attendance/in
  Future<Attendance> clockIn({double? latitude, double? longitude}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/in');
    final response = await http
        .post(
          uri,
          headers: _authHeaders(),
          body: jsonEncode(_gpsPayload(latitude, longitude)),
        )
        .timeout(_timeout);

    _throwIfRequestFailed(response);

    return Attendance.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // POST /api/attendance/out
  Future<Attendance> clockOut({double? latitude, double? longitude}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/out');
    final response = await http
        .post(
          uri,
          headers: _authHeaders(),
          body: jsonEncode(_gpsPayload(latitude, longitude)),
        )
        .timeout(_timeout);

    _throwIfRequestFailed(response);

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

    final response = await http
        .get(uri, headers: _authHeaders())
        .timeout(_timeout);

    _throwIfRequestFailed(response);

    return AttendanceHistoryResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // GET /api/attendance/summary
  Future<AttendanceSummaryTotals> getAttendanceSummary() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/summary');
    final response = await http
        .get(uri, headers: _authHeaders())
        .timeout(_timeout);

    _throwIfRequestFailed(response);

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

  void _throwIfRequestFailed(http.Response response) {
    final parsed = _parseErrorPayload(response.body);

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

  _ParsedApiError _parseErrorPayload(String body,
      {String fallback = 'Request failed.'}) {
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

        final message = (json['message'] ??
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
    } catch (_) {}

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

class _ParsedApiError {
  final String? message;
  final String? code;
  final String? detail;
  final Map<String, dynamic>? metadata;

  _ParsedApiError({
    this.message,
    this.code,
    this.detail,
    this.metadata,
  });
}
