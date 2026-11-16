import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchStatistics();
  }

  Future<List<Map<String, dynamic>>> _fetchStatistics() {
    return Future.wait([
      ApiService.getStatistics('tasks'),
      ApiService.getStatistics('assignments'),
      ApiService.getStatistics('deadlines'),
    ]);
  }

  void _reload() {
    setState(() {
      _future = _fetchStatistics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Thống kê công việc'),
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới thống kê',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Không tải được thống kê: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final tasks = data[0];
          final assignments = data[1];
          final deadlines = data[2];
          final byStatus = tasks['byStatus'] is Map
              ? tasks['byStatus'] as Map
              : <String, dynamic>{};

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _card('Tổng số công việc', '${tasks['total'] ?? 0}', Icons.task_alt),
              const SizedBox(height: 8),
              _card('Chưa thực hiện', '${byStatus['todo'] ?? 0}', Icons.pending_actions),
              _card('Đang thực hiện', '${byStatus['in_progress'] ?? 0}', Icons.timelapse),
              _card('Đã hoàn thành', '${byStatus['completed'] ?? 0}', Icons.check_circle_outline),
              const Divider(height: 30),
              _card('Công việc tôi tạo', '${assignments['created'] ?? 0}', Icons.edit_note),
              _card('Công việc được giao', '${assignments['assigned'] ?? 0}', Icons.group),
              _card('Tôi phụ trách chính', '${assignments['primary'] ?? 0}', Icons.star_outline),
              const Divider(height: 30),
              _card('Sắp đến hạn (24 giờ)', '${deadlines['dueSoon'] ?? 0}', Icons.schedule),
              _card('Quá hạn', '${deadlines['overdue'] ?? 0}', Icons.warning_amber),
            ],
          );
        },
      ),
    );
  }

  Widget _card(String label, String number, IconData icon) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1769E8)),
        title: Text(label),
        trailing: Text(
          number,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
