
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() =>
      _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = ApiService.getTasks();
  }

  // Tải lại danh sách công việc
  void reload() {
    setState(() {
      future = ApiService.getTasks();
    });
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
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        actions: [
          IconButton(
            onPressed: reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          // Đang tải dữ liệu
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Lỗi kết nối API
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

          // Chưa có công việc
          if (tasks.isEmpty) {
            return const Center(
              child: Text('Chưa có công việc nào.'),
            );
          }

          // Danh sách công việc
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
                  child: ListTile(
                    title: Text(
                      '${task['title'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${status(task['status']?.toString())}'
                          ' • Ưu tiên: '
                          '${priority(task['priority']?.toString())}',
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                    ),
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
