import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();
  static const _storage = FlutterSecureStorage();

  // Android Emulator truy cập máy Windows qua 10.0.2.2.
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  static Future<String?> getToken() => _storage.read(key: 'token');
  static Future<void> logout() => _storage.delete(key: 'token');

  static Future<Map<String, dynamic>> _send(
    String method, String path, {
    Map<String, dynamic>? data,
    bool auth = false,
    Map<String, String>? query,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Vui lòng đăng nhập lại.');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    final base = Uri.parse('$baseUrl$path');
    final uri = query == null || query.isEmpty
        ? base : base.replace(queryParameters: query);
    try {
      late http.Response response;
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await http.post(uri, headers: headers,
              body: jsonEncode(data ?? {})).timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers,
              body: jsonEncode(data ?? {})).timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers,
              body: jsonEncode(data ?? {})).timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          throw Exception('Phương thức API không được hỗ trợ.');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Phản hồi API không hợp lệ.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception((decoded['message'] ?? 'Lỗi ${response.statusCode}').toString());
      }
      return decoded;
    } on FormatException {
      throw Exception('Phản hồi API không đúng định dạng JSON.');
    }
  }

  static Future<void> register(String fullName, String email, String password) async {
    final r = await _send('POST', '/auth/register', data: {
      'fullName': fullName, 'email': email.trim().toLowerCase(), 'password': password,
    });
    await _storage.write(key: 'token', value: r['token'] as String);
  }
  static Future<void> login(String email, String password) async {
    final r = await _send('POST', '/auth/login', data: {
      'email': email.trim().toLowerCase(), 'password': password,
    });
    await _storage.write(key: 'token', value: r['token'] as String);
  }
  static Future<Map<String, dynamic>> getMe() async {
    final r = await _send('GET', '/auth/me', auth: true);
    return Map<String, dynamic>.from(r['user'] as Map);
  }
  static Future<Map<String, dynamic>> updateMe(String fullName) async {
    final r = await _send('PUT', '/auth/me', auth: true, data: { 'fullName': fullName });
    return Map<String, dynamic>.from(r['user'] as Map);
  }
  static Future<void> changePassword(String oldPassword, String newPassword) async {
    await _send('PUT', '/auth/change-password', auth: true, data: {
      'oldPassword': oldPassword, 'newPassword': newPassword,
    });
  }
  static Future<List<Map<String, dynamic>>> searchUsers(String q) async {
    final r = await _send('GET', '/users/search', auth: true, query: {'q': q});
    return (r['users'] as List? ?? []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }

  static Future<List<Map<String, dynamic>>> getTasks({
    String q = '', String status = '', String priority = '',
    String scope = 'all', String sortBy = 'createdAt', String order = 'desc',
    String assigneeId = '',
  }) async {
    final r = await _send('GET', '/tasks', auth: true, query: {
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (status.isNotEmpty) 'status': status,
      if (priority.isNotEmpty) 'priority': priority,
      if (assigneeId.isNotEmpty) 'assignee': assigneeId,
      'scope': scope, 'sortBy': sortBy, 'order': order,
    });
    return (r['tasks'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }
  static Future<Map<String, dynamic>> getTask(String id) async {
    final r = await _send('GET', '/tasks/${Uri.encodeComponent(id)}', auth: true);
    return Map<String, dynamic>.from(r['task'] as Map);
  }
  static Future<Map<String, dynamic>> createTask({
    required String title, String description = '', String priority = 'medium',
    String status = 'todo', DateTime? startDate, DateTime? dueDate,
  }) async {
    final r = await _send('POST', '/tasks', auth: true, data: {
      'title': title.trim(), 'description': description.trim(),
      'priority': priority, 'status': status,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
    });
    return Map<String, dynamic>.from(r['task'] as Map);
  }
  static Future<Map<String, dynamic>> updateTask({
    required String id, required String title, required String description,
    required String priority, required String status,
    DateTime? startDate, DateTime? dueDate,
  }) async {
    final r = await _send('PUT', '/tasks/${Uri.encodeComponent(id)}', auth: true, data: {
      'title': title.trim(), 'description': description.trim(),
      'priority': priority, 'status': status,
      'startDate': startDate?.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
    });
    return Map<String, dynamic>.from(r['task'] as Map);
  }
  static Future<void> deleteTask(String id) async {
    await _send('DELETE', '/tasks/${Uri.encodeComponent(id)}', auth: true);
  }
  static Future<Map<String, dynamic>> updateTaskStatus(String id, String status) =>
      _send('PATCH', '/tasks/${Uri.encodeComponent(id)}/status', auth: true,
          data: {'status': status});

  static Future<Map<String, dynamic>> assignTask({
    required String taskId, required List<String> emails, String? primaryEmail,
  }) => _send('POST', '/tasks/${Uri.encodeComponent(taskId)}/assignees',
      auth: true, data: {'emails': emails, 'primaryEmail': primaryEmail});
  static Future<Map<String, dynamic>> getTaskAssignees({required String taskId}) =>
      _send('GET', '/tasks/${Uri.encodeComponent(taskId)}/assignees', auth: true);
  static Future<void> removeAssignee(String taskId, String userId) async {
    await _send('DELETE', '/tasks/${Uri.encodeComponent(taskId)}/assignees/${Uri.encodeComponent(userId)}', auth: true);
  }

  static Future<Map<String, dynamic>> shareTask({
    required String taskId, required String email, required String permission,
  }) => _send('POST', '/tasks/${Uri.encodeComponent(taskId)}/shares',
      auth: true, data: {'email': email.trim().toLowerCase(), 'permission': permission});

  static Future<Map<String, dynamic>> shareTaskMultiple({
    required String taskId, required List<String> emails, required String permission,
  }) => _send('POST', '/tasks/${Uri.encodeComponent(taskId)}/shares',
      auth: true, data: {'emails': emails.map((x) => x.trim().toLowerCase()).toList(),
        'permission': permission});
  static Future<Map<String, dynamic>> getTaskShares({required String taskId}) =>
      _send('GET', '/tasks/${Uri.encodeComponent(taskId)}/shares', auth: true);
  static Future<Map<String, dynamic>> revokeTaskShare({
    required String taskId, required String shareId,
  }) => _send('DELETE', '/tasks/${Uri.encodeComponent(taskId)}/shares/${Uri.encodeComponent(shareId)}', auth: true);
  static Future<void> updateSharePermission(String taskId, String shareId, String permission) async {
    await _send('PATCH', '/tasks/${Uri.encodeComponent(taskId)}/shares/${Uri.encodeComponent(shareId)}',
        auth: true, data: {'permission': permission});
  }

  static Future<Map<String, dynamic>> getNotifications() =>
      _send('GET', '/notifications', auth: true);
  static Future<Map<String, dynamic>> markNotificationRead(String id) =>
      _send('PUT', '/notifications/${Uri.encodeComponent(id)}/read', auth: true);
  static Future<void> markAllNotificationsRead() async {
    await _send('PATCH', '/notifications/read-all', auth: true);
  }
  static Future<Map<String, dynamic>> getStatistics(String category) =>
      _send('GET', '/statistics/$category', auth: true);
  static Future<List<Map<String, dynamic>>> getTaskActivities(String id) async {
    final r = await _send('GET', '/tasks/${Uri.encodeComponent(id)}/activities', auth: true);
    return (r['activities'] as List? ?? []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }
  static Future<List<Map<String, dynamic>>> getTaskEmailLogs(String id) async {
    final r = await _send('GET', '/tasks/${Uri.encodeComponent(id)}/email-logs', auth: true);
    return (r['logs'] as List? ?? []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
  }
}
