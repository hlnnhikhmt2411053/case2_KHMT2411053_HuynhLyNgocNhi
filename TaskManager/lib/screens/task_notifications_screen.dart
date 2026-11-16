import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'task_detail_screen.dart';

class TaskNotificationsScreen extends StatefulWidget {
  const TaskNotificationsScreen({super.key});
  @override
  State<TaskNotificationsScreen> createState() => _TaskNotificationsScreenState();
}

class _TaskNotificationsScreenState extends State<TaskNotificationsScreen> {
  late Future<Map<String, dynamic>> _future;
  final Set<String> _busyIds = {};
  bool _allBusy = false;
  @override
  void initState() { super.initState(); _future = ApiService.getNotifications(); }
  void _refresh() {
    if (!mounted) return;
    final next = ApiService.getNotifications();
    setState(() {
      _future = next;
    });
  }
  Future<void> _readOne(Map<String, dynamic> n) async {
    final id = (n['_id'] ?? '').toString();
    if (id.isEmpty || _busyIds.contains(id)) {
      return;
    }
    setState(() => _busyIds.add(id));
    try {
      if (n['isRead'] != true) {
        await ApiService.markNotificationRead(id);
      }
      if (!mounted) {
        return;
      }
      _refresh();
      final taskId = (n['taskId'] ?? '').toString();
      if (taskId.isNotEmpty) {
        await Navigator.push(context, MaterialPageRoute(
          builder: (_) => TaskDetailScreen(id: taskId)));
      }
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }
  Future<void> _readAll() async {
    if (_allBusy) {
      return;
    }
    setState(() => _allBusy = true);
    try { await ApiService.markAllNotificationsRead(); _refresh(); }
    catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _allBusy = false);
      }
    }
  }
  String _format(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) {
      return '';
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8FF),
    appBar: AppBar(title: const Text('Thông báo'), centerTitle: true,
      backgroundColor: const Color(0xFF1769E8), foregroundColor: Colors.white,
      actions: [IconButton(tooltip: 'Làm mới', onPressed: _refresh, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Không tải được thông báo: ${snapshot.error}', textAlign: TextAlign.center),
          TextButton(onPressed: _refresh, child: const Text('Thử lại')),
        ]));
      }
      final data = snapshot.data ?? {};
      final list = (data['notifications'] as List? ?? [])
          .whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final unread = (data['unreadCount'] as num?)?.toInt() ?? 0;
      if (list.isEmpty) {
        return const Center(child: Text('Bạn chưa có thông báo nào.'));
      }
      return RefreshIndicator(onRefresh: () async {
        final next = ApiService.getNotifications();
        setState(() {
          _future = next;
        });
        try { await next; } catch (_) {}
      }, child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: Text('Chưa đọc: $unread', style: const TextStyle(fontWeight: FontWeight.bold))),
          TextButton.icon(onPressed: unread > 0 && !_allBusy ? _readAll : null,
            icon: const Icon(Icons.done_all), label: const Text('Đọc tất cả')),
        ]),
        const SizedBox(height: 8),
        for (final n in list)
          Card(color: n['isRead'] == true ? Colors.white : const Color(0xFFE8F1FF),
            child: ListTile(
              leading: Icon(n['type'] == 'task_shared' ? Icons.share_outlined : Icons.notifications_active_outlined,
                color: const Color(0xFF1769E8)),
              title: Text('${n['title'] ?? 'Thông báo'}',
                style: TextStyle(fontWeight: n['isRead'] == true ? FontWeight.normal : FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 5), Text('${n['message'] ?? ''}'),
                const SizedBox(height: 5), Text(_format(n['createdAt']),
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Text(n['isRead'] == true ? 'Đã đọc' : 'Chạm để đọc / mở công việc',
                  style: const TextStyle(color: Color(0xFF1769E8), fontSize: 12)),
              ]),
              trailing: _busyIds.contains('${n['_id']}')
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : n['isRead'] == true ? const Icon(Icons.check_circle_outline, color: Colors.green)
                : const Icon(Icons.circle, size: 10, color: Color(0xFF1769E8)),
              onTap: () => _readOne(n),
            )),
      ]));
    }),
  );
}
