import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Api {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('CLINEXA_API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') return origin;
    }
    return 'http://127.0.0.1:8000';
  }

  static const vault = FlutterSecureStorage();
  static String? _accessToken;
  static Future<void>? _refreshing;
  static bool _configured = false;

  static bool can(String permission) => hasAnyRole(['Super Administrator']) ||
      (List<String>.from((currentUser?['permissions'] as List?) ?? []).contains(permission) ||
       List<String>.from((currentUser?['permissions'] as List?) ?? []).contains('*'));
  static Map<String, dynamic>? currentUser;

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 120),
    headers: {'Accept': 'application/json'},
  ));

  static Future<void> configure() async {
    dio.options.baseUrl = baseUrl;
    if (!_configured) {
      _configured = true;
      dio.interceptors.add(InterceptorsWrapper(onError: (error, handler) async {
        final request = error.requestOptions;
        if (error.response?.statusCode != 401 || ['/auth/login', '/auth/register', '/auth/refresh'].any(request.path.endsWith) ||
            request.extra['retried'] == true) {
          handler.next(error);
          return;
        }
        try {
          // One rotating refresh token is shared by simultaneous requests.
          _refreshing ??= _refreshSession();
          await _refreshing;
          request.extra['retried'] = true;
          if (request.data is FormData) request.data = (request.data as FormData).clone();
          request.headers['Authorization'] = 'Bearer $_accessToken';
          handler.resolve(await dio.fetch<dynamic>(request));
        } catch (_) {
          handler.next(error);
        }
      }));
    }
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['access_token','refresh_token','current_user']) {
      final legacy = prefs.getString(key);
      if (legacy != null && await vault.read(key:key) == null) await vault.write(key:key,value:legacy);
      if (legacy != null) await prefs.remove(key);
    }
    _accessToken = await vault.read(key:'access_token');
    final cachedUser = await vault.read(key:'current_user');
    if (cachedUser != null) {
      try {
        currentUser = Map<String, dynamic>.from(jsonDecode(cachedUser) as Map);
      } catch (_) {
        currentUser = null;
      }
    }
    if (_accessToken != null) {
      dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }
  }

  static Future<void> _refreshSession() async {
    try {
      final token = await vault.read(key:'refresh_token');
      if (token == null) throw StateError('Sign in again to continue.');
      final client = Dio(BaseOptions(baseUrl: baseUrl,
          connectTimeout: Duration(seconds: 10), receiveTimeout: Duration(seconds: 15)));
      try {
        final response = await client.post('/api/v1/auth/refresh', data: {'refresh_token': token});
        // Do not revive a session that was signed out while refresh was running.
        if (await vault.read(key:'refresh_token') == token) {
          await saveTokens(Map<String, dynamic>.from(response.data as Map));
        } else {
          throw StateError('Session ended.');
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) await logout(revoke:false);
        rethrow;
      } finally {
        client.close();
      }
    } finally {
      _refreshing = null;
    }
  }

  static Future<void> saveTokens(Map<String, dynamic> data) async {
    _accessToken = data['access_token'] as String;
    await vault.write(key:'access_token',value:_accessToken!);
    await vault.write(key:'refresh_token',value:data['refresh_token'] as String);
    dio.options.headers['Authorization'] = 'Bearer $_accessToken';
  }

  static Future<Map<String, dynamic>> loadProfile() async {
    final response = await dio.get('/api/v1/auth/me');
    currentUser = Map<String, dynamic>.from(response.data as Map);
    await vault.write(key:'current_user',value:jsonEncode(currentUser));
    return currentUser!;
  }

  static List<String> get roles =>
      List<String>.from((currentUser?['roles'] as List?) ?? <String>[]);

  static bool hasAnyRole(Iterable<String> names) {
    final normalized = roles.map((e) => e.toLowerCase()).toSet();
    return names.any((name) => normalized.contains(name.toLowerCase()));
  }

  static Map<String, String> get authHeaders =>
      _accessToken == null ? {} : {'Authorization': 'Bearer $_accessToken'};

  static Future<void> logout({bool revoke=true}) async {
    if (revoke && _accessToken != null) {
      final client = Dio(BaseOptions(baseUrl:baseUrl, connectTimeout:Duration(seconds:5), receiveTimeout:Duration(seconds:5), headers:authHeaders));
      try { await client.post("/api/v1/account/logout"); } catch (_) {} finally { client.close(); }
    }
    await vault.delete(key:"access_token");
    await vault.delete(key:"refresh_token");
    await vault.delete(key:"current_user");
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('current_user');
    _accessToken = null;
    currentUser = null;
    dio.options.headers.remove('Authorization');
  }

  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (error.response?.statusCode == 401) return 'Your session has ended. Sign in again to continue.';
      if (data is Map && data['detail'] is List) {
        return (data['detail'] as List).map((x) => x is Map ? x['msg']?.toString() ?? 'Invalid value' : x.toString()).join(' • ');
      }
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (error.type == DioExceptionType.connectionError || error.response == null) {
        return 'Cannot reach the Clinexa backend. Keep FastAPI running and check the phone USB connection.';
      }
    }
    return error.toString();
  }
}
