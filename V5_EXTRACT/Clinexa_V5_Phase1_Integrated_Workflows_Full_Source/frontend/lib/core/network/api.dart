import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Api {
  static const baseUrl = String.fromEnvironment(
    'CLINEXA_API_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static String? _accessToken;
  static Map<String, dynamic>? currentUser;

  static final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Accept': 'application/json'},
  ));

  static Future<void> configure() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    final cachedUser = prefs.getString('current_user');
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

  static Future<void> saveTokens(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = data['access_token'] as String;
    await prefs.setString('access_token', _accessToken!);
    await prefs.setString('refresh_token', data['refresh_token'] as String);
    dio.options.headers['Authorization'] = 'Bearer $_accessToken';
  }

  static Future<Map<String, dynamic>> loadProfile() async {
    final response = await dio.get('/api/v1/auth/me');
    currentUser = Map<String, dynamic>.from(response.data as Map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(currentUser));
    return currentUser!;
  }

  static List<String> get roles =>
      List<String>.from((currentUser?['roles'] as List?) ?? const <String>[]);

  static bool hasAnyRole(Iterable<String> names) {
    final normalized = roles.map((e) => e.toLowerCase()).toSet();
    return names.any((name) => normalized.contains(name.toLowerCase()));
  }

  static Map<String, String> get authHeaders =>
      _accessToken == null ? const {} : {'Authorization': 'Bearer $_accessToken'};

  static Future<void> logout() async {
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
      if (data is Map && data['detail'] != null) return data['detail'].toString();
      if (error.type == DioExceptionType.connectionError || error.response == null) {
        return 'Cannot reach the Clinexa backend. Keep FastAPI running and check the phone USB connection.';
      }
    }
    return error.toString();
  }
}
