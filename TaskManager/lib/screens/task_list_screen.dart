import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});
  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}
class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() { super.initState(); reload(); }
  void reload() { setState(() => future = ApiService.getTasks()); }
  Future<void> logout() async {
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }
  String status(String? value) => switch (value) { 'completed' => 'Đã hoàn thành', 'in_progress' => 'Đang thực hiện', _ => 'Chưa thực hiện' };
  String priority(String? value) => switch (value) { 'high' => 'Cao', 'low' => 'Thấp', _ => 'Trung bình' };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danh sách công việc'), actions: [IconButton(onPressed: reload, icon: const Icon(Icons.refresh)), IconButton(onPressed: logout, icon: const Icon(Icons.logout))]),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Không tải được công việc: ${snapshot.error}', textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: reload, child: const Text('Thử lại'))])));
      final tasks = snapshot.data ?? [];
      if (tasks.isEmpty) return const Center(child: Text('Chưa có công việc nào.'));
      return RefreshIndicator(onRefresh: () async { reload(); await future; }, child: ListView.separated(
        padding: const EdgeInsets.all(16), itemCount: tasks.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final task = tasks[i];
          return Card(child: ListTile(
            title: Text('${task['title'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${status(task['status']?.toString())} • Ưu tiên: ${priority(task['priority']?.toString())}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskDetailScreen(id: task['_id'].toString()))),
          ));
        },
      ));
    }),
  );
}
