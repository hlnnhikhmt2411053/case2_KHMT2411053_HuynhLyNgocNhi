
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static const storage = FlutterSecureStorage();

  // Android Emulator sử dụng 10.0.2.2 để truy cập localhost máy tính.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }

    return 'http://localhost:3000/api';
  }

  // Lấy token
  static Future<String?> getToken() {
    return storage.read(key: 'token');
  }

  // Đăng xuất
  static Future<void> logout() {
    return storage.delete(key: 'token');
  }

  // Hàm gửi yêu cầu API
  static Future<Map<String, dynamic>> _send(
      String method,
      String path, {
        Map<String, dynamic>? data,
        bool auth = false,
      }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await getToken();

      if (token == null) {
        throw Exception('Vui lòng đăng nhập lại.');
      }

      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final uri = Uri.parse('$baseUrl$path');

      late http.Response response;

      if (method == 'GET') {
        response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 15));
      } else if (method == 'POST') {
        response = await http
            .post(
          uri,
          headers: headers,
          body: jsonEncode(data ?? {}),
        )
            .timeout(const Duration(seconds: 15));
      } else {
        throw Exception('Phương thức API không được hỗ trợ.');
      }

      final body = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (body is! Map<String, dynamic>) {
        throw Exception('Dữ liệu API không hợp lệ.');
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          (body['message'] ?? 'Lỗi ${response.statusCode}')
              .toString(),
        );
      }

      return body;
    } on FormatException {
      throw Exception('Phản hồi API không hợp lệ.');
    }
  }

  // ==============================
  // BUỔI 1: ĐĂNG KÝ
  // ==============================
  static Future<void> register(
      String fullName,
      String email,
      String password,
      ) async {
    final result = await _send(
      'POST',
      '/auth/register',
      data: {
        'fullName': fullName,
        'email': email,
        'password': password,
      },
    );

    await storage.write(
      key: 'token',
      value: result['token'] as String,
    );
  }

  // ==============================
  // BUỔI 1: ĐĂNG NHẬP
  // ==============================
  static Future<void> login(
      String email,
      String password,
      ) async {
    final result = await _send(
      'POST',
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    await storage.write(
      key: 'token',
      value: result['token'] as String,
    );
  }

  // ==============================
  // BUỔI 1: DANH SÁCH CÔNG VIỆC
  // ==============================
  static Future<List<Map<String, dynamic>>> getTasks() async {
    final result = await _send(
      'GET',
      '/tasks',
      auth: true,
    );

    final list = result['tasks'] as List<dynamic>? ?? [];

    return list
        .map(
          (e) => Map<String, dynamic>.from(e as Map),
    )
        .toList();
  }

  // ==============================
  // BUỔI 1: CHI TIẾT CÔNG VIỆC
  // ==============================
  static Future<Map<String, dynamic>> getTask(String id) async {
    final result = await _send(
      'GET',
      '/tasks/${Uri.encodeComponent(id)}',
      auth: true,
    );

    return Map<String, dynamic>.from(
      result['task'] as Map,
    );
  }

  // ==============================
  // BUỔI 2: THÊM CÔNG VIỆC
  // ==============================
  static Future<Map<String, dynamic>> createTask({
    required String title,
    String description = '',
    String priority = 'medium',
    String status = 'todo',
    DateTime? startDate,
    DateTime? dueDate,
  }) async {
    final result = await _send(
      'POST',
      '/tasks',
      auth: true,
      data: {
        'title': title.trim(),
        'description': description.trim(),
        'priority': priority,
        'status': status,
        if (startDate != null)
          'startDate': startDate.toIso8601String(),
        if (dueDate != null)
          'dueDate': dueDate.toIso8601String(),
      },
    );

    return Map<String, dynamic>.from(
      result['task'] as Map,
    );
  }
}
