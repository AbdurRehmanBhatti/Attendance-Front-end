import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class AuthSessionStorage {
  AuthSessionStorage._();

  static const _sessionKey = 'auth_user_session';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _secureStorage = FlutterSecureStorage();

  static Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = user.toJson();
    final refreshToken = (sessionJson.remove('refreshToken') ?? '').toString();

    await prefs.setString(_sessionKey, jsonEncode(sessionJson));

    if (refreshToken.trim().isEmpty) {
      await _secureStorage.delete(key: _refreshTokenKey);
      return;
    }

    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  static Future<User?> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      var refreshToken = (await _secureStorage.read(key: _refreshTokenKey)) ??
          '';

      // One-time migration for sessions created before secure refresh-token storage.
      if (refreshToken.trim().isEmpty) {
        final legacyRefresh = json['refreshToken']?.toString() ?? '';
        if (legacyRefresh.trim().isNotEmpty) {
          refreshToken = legacyRefresh;
          await _secureStorage.write(key: _refreshTokenKey, value: legacyRefresh);
          json.remove('refreshToken');
          await prefs.setString(_sessionKey, jsonEncode(json));
        }
      }

      json['refreshToken'] = refreshToken;
      return User.fromJson(json);
    } catch (_) {
      await prefs.remove(_sessionKey);
      await _secureStorage.delete(key: _refreshTokenKey);
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
