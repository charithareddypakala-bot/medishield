import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool isActive;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['_id'] ?? json['id'];
    final rawName = json['name'] ?? 'User';
    final rawEmail = json['email'] ?? '';
    final rawPhone = json['phone'] ?? '';
    final rawRole = (json['role'] ?? 'patient').toString();

    return AppUser(
      id: rawId?.toString() ?? '',
      name: rawName.toString(),
      email: rawEmail.toString(),
      phone: rawPhone.toString(),
      role: rawRole,
      isActive: json['isActive'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'isActive': isActive,
      };
}

class AppSession {
  AppSession._();

  static final AppSession instance = AppSession._();

  static const String _accessTokenKey = 'medishield_access_token';
  static const String _refreshTokenKey = 'medishield_refresh_token';
  static const String _userKey = 'medishield_user';

  SharedPreferences? _prefs;
  void Function()? onSessionExpired;
  bool _isExpiringSession = false;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  String? get accessToken => _prefs?.getString(_accessTokenKey);
  String? get refreshToken => _prefs?.getString(_refreshTokenKey);

  AppUser? get currentUser {
    final rawUser = _prefs?.getString(_userKey);
    if (rawUser == null || rawUser.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        return AppUser.fromJson(decoded);
      }
      if (decoded is Map) {
        return AppUser.fromJson(Map<String, dynamic>.from(decoded));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  Future<void> saveSession({
    required AppUser user,
    required String accessToken,
    required String refreshToken,
  }) async {
    await init();
    _isExpiringSession = false;
    await _prefs!.setString(_accessTokenKey, accessToken);
    await _prefs!.setString(_refreshTokenKey, refreshToken);
    await _prefs!.setString(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    await init();
    await _prefs!.remove(_accessTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.remove(_userKey);
  }

  Future<void> expireSession() async {
    if (_isExpiringSession) return;
    _isExpiringSession = true;
    await clear();
    onSessionExpired?.call();
  }
}

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String get baseUrl {
    const envUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    if (envUrl.isNotEmpty) {
      return envUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 'http://localhost:5000/api/v1';
    }

    return 'http://10.0.2.2:5000/api/v1';
  }

  Future<Map<String, dynamic>> get(
    String path, {
    bool requireAuth = true,
  }) async {
    return _send('GET', path, requireAuth: requireAuth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    return _send('POST', path, body: body, requireAuth: requireAuth);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    return _send('PUT', path, body: body, requireAuth: requireAuth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
  }) async {
    return _send('PATCH', path, body: body, requireAuth: requireAuth);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool requireAuth = true,
  }) async {
    return _send('DELETE', path, requireAuth: requireAuth);
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requireAuth = true,
    bool retryAfterRefresh = true,
  }) async {
    final uri = Uri.parse(path.startsWith('http') ? path : '$baseUrl$path');

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (requireAuth) {
      final token = AppSession.instance.accessToken;
      if (token == null || token.isEmpty) {
        throw const ApiException('Authentication required');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;

    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(
            const Duration(seconds: 20),
          );
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          response = await http.patch(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          ).timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(
            const Duration(seconds: 20),
          );
          break;
        default:
          throw const ApiException('Unsupported request method');
      }
    } on Exception {
      throw const ApiException('Unable to connect to the MediShield backend');
    }

    if (response.statusCode == 401 && requireAuth && retryAfterRefresh) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        return _send(
          method,
          path,
          body: body,
          requireAuth: requireAuth,
          retryAfterRefresh: false,
        );
      }
      await AppSession.instance.expireSession();
      throw const ApiException('Your session expired. Please sign in again.');
    }
    if (response.statusCode == 401 && requireAuth) {
      await AppSession.instance.expireSession();
      throw const ApiException('Your session expired. Please sign in again.');
    }

    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required List<int> bytes,
    required String fileName,
    bool retryAfterRefresh = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = AppSession.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentication required');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    http.Response response;
    try {
      response = await http.Response.fromStream(await request.send()).timeout(
        const Duration(seconds: 180),
      );
    } on Exception {
      throw const ApiException('Unable to upload to the MediShield backend');
    }

    if (response.statusCode == 401 && retryAfterRefresh) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        return postMultipart(
          path,
          bytes: bytes,
          fileName: fileName,
          retryAfterRefresh: false,
        );
      }
      await AppSession.instance.expireSession();
      throw const ApiException('Your session expired. Please sign in again.');
    }

    if (response.statusCode == 401) {
      await AppSession.instance.expireSession();
      throw const ApiException('Your session expired. Please sign in again.');
    }

    return _decodeResponse(response);
  }

  Future<bool> _refreshAccessToken() async {
    final refreshToken = AppSession.instance.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh-token'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refreshToken': refreshToken}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(decoded['data'] ?? {});
      final accessToken = data['accessToken']?.toString() ?? '';
      final user = AppSession.instance.currentUser;
      if (accessToken.isEmpty || user == null) return false;

      await AppSession.instance.saveSession(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {'data': decoded};
    }

    final errorBody = response.body.trim();
    String message = 'Request failed';

    if (errorBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(errorBody);
        if (decoded is Map) {
          final payload = Map<String, dynamic>.from(decoded);
          final candidate = payload['message'];
          if (candidate is String && candidate.isNotEmpty) {
            message = candidate;
          }
        }
      } catch (_) {}
    }

    throw ApiException(message);
  }
}
