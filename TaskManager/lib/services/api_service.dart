import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();
  static const storage = FlutterSecureStorage();
  // Android emulator: localhost của máy tính = 10.0.2.2.
  // Điện thoại thật: đổi thành IP LAN của máy chạy Node.js.
  static String get baseUrl => kIsWeb ? 'http://localhost:3000/api' :
      defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:3000/api' : 'http://localhost:3000/api';

  static Future<String?> getToken() => storage.read(key: 'token');
  static Future<void> logout() => storage.delete(key: 'token');

  static Future<Map<String, dynamic>> _send(String method, String path, {Map<String, dynamic>? data, bool auth = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token == null) throw Exception('Vui lòng đăng nhập lại.');
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final uri = Uri.parse('$baseUrl$path');
      late http.Response response;
      if (method == 'GET') {
        response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      } else {
        response = await http.post(uri, headers: headers, body: jsonEncode(data ?? {})).timeout(const Duration(seconds: 15));
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) throw Exception('Dữ liệu API không hợp lệ.');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception((body['message'] ?? 'Lỗi ${response.statusCode}').toString());
      }
      return body;
    } catch (e) {
      if (e is FormatException) throw Exception('Phản hồi API không hợp lệ.');
      rethrow;
    }
  }

  static Future<void> register(String fullName, String email, String password) async {
    final result = await _send('POST', '/auth/register', data: {'fullName': fullName, 'email': email, 'password': password});
    await storage.write(key: 'token', value: result['token'] as String);
  }

  static Future<void> login(String email, String password) async {
    final result = await _send('POST', '/auth/login', data: {'email': email, 'password': password});
    await storage.write(key: 'token', value: result['token'] as String);
  }

  static Future<List<Map<String, dynamic>>> getTasks() async {
    final result = await _send('GET', '/tasks', auth: true);
    final list = result['tasks'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>> getTask(String id) async {
    final result = await _send('GET', '/tasks/${Uri.encodeComponent(id)}', auth: true);
    return Map<String, dynamic>.from(result['task'] as Map);
  }
}
