import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/attendance.dart';

class ApiService {
  static const _timeout = Duration(seconds: 15);

  static final Map<String, String> _headers = {
    HttpHeaders.contentTypeHeader: 'application/json',
  };

  // POST /api/auth/login
  Future<int> login(String username, String password) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');
    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['userId'] as int;
  }

  // POST /api/attendance/in
  Future<Attendance> clockIn(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/in');
    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'userId': userId}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    return Attendance.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // POST /api/attendance/out
  Future<Attendance> clockOut(int userId) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/attendance/out');
    final response = await http
        .post(
          uri,
          headers: _headers,
          body: jsonEncode({'userId': userId}),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    return Attendance.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // GET /api/attendance/today/{userId}
  Future<List<Attendance>> getTodayAttendance(int userId) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/api/attendance/today/$userId',
    );
    final response = await http.get(uri, headers: _headers).timeout(_timeout);

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _parseError(response.body));
    }

    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => Attendance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _parseError(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, dynamic>) {
        return (json['detail'] ?? json['error'] ?? json['title'] ?? body)
            .toString();
      }
    } catch (_) {}
    return body;
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
