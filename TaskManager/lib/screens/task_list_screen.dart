
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'login_screen.dart';
import 'task_detail_screen.dart';
import 'task_create_screen.dart';
import 'task_edit_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = ApiService.getTasks();
  }

  // Làm mới danh sách công việc
  void reload() {
    setState(() {
      future = ApiService.getTasks();
    });
  }

  // BUỔI 2: Mở màn hình thêm công việc
  Future<void> openCreateTask() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const TaskCreateScreen(),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thêm công việc thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // BUỔI 2: Mở màn hình sửa công việc
  Future<void> openEditTask(Map<String, dynamic> task) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(
          id: task['_id'].toString(),
        ),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật công việc thành công!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Đăng xuất
  Future<void> logout() async {
    await ApiService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (_) => false,
    );
  }

  // Hiển thị trạng thái
  String status(String? value) {
    switch (value) {
      case 'completed':
        return 'Đã hoàn thành';
      case 'in_progress':
        return 'Đang thực hiện';
      default:
        return 'Chưa thực hiện';
    }
  }

  // Hiển thị độ ưu tiên
  String priority(String? value) {
    switch (value) {
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      default:
        return 'Trung bình';
    }
  }

  // Mở chi tiết công việc
  void openTask(Map<String, dynamic> task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          id: task['_id'].toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),

      appBar: AppBar(
        title: const Text(
          'Danh sách công việc',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      // Nút + Thêm công việc
      floatingActionButton: FloatingActionButton(
        onPressed: openCreateTask,
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
        tooltip: 'Thêm công việc',
        child: const Icon(Icons.add),
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Không tải được công việc: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có công việc nào.\n'
                    'Nhấn dấu + để thêm công việc mới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final next = ApiService.getTasks();

              setState(() {
                future = next;
              });

              await next;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              separatorBuilder: (context, index) =>
              const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = tasks[index];

                return Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F0FF),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: Color(0xFF1769E8),
                      ),
                    ),
                    title: Text(
                      '${task['title'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${status(task['status']?.toString())}'
                            ' • Ưu tiên: '
                            '${priority(task['priority']?.toString())}',
                      ),
                    ),

                    // BUỔI 2: Nút sửa công việc
                    trailing: IconButton(
                      tooltip: 'Sửa công việc',
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF1769E8),
                      ),
                      onPressed: () => openEditTask(task),
                    ),

                    // Giữ nguyên chức năng xem chi tiết
                    onTap: () => openTask(task),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
