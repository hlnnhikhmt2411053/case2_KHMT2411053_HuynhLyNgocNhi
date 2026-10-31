import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final String id;
  const TaskDetailScreen({super.key, required this.id});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}
class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() { super.initState(); future = ApiService.getTask(widget.id); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết công việc')),
    body: FutureBuilder<Map<String, dynamic>>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Lỗi: ${snapshot.error}'));
      final task = snapshot.data!;
      return ListView(padding: const EdgeInsets.all(20), children: [
        Text('${task['title'] ?? ''}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 20),
        const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${task['description'] ?? ''}'),
        const SizedBox(height: 20),
        Text('Trạng thái: ${task['status'] ?? 'todo'}'),
        const SizedBox(height: 8),
        Text('Ưu tiên: ${task['priority'] ?? 'medium'}'),
        const SizedBox(height: 8),
        Text('Ngày tạo: ${task['createdAt'] ?? ''}'),
      ]);
    }),
  );
}
