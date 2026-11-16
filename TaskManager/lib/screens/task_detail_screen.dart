import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'task_edit_screen.dart';
import 'task_assign_screen.dart';
import 'task_share_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String id;
  const TaskDetailScreen({super.key, required this.id});
  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}
class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _updating = false;
  @override
  void initState() {
    super.initState();
    _future = ApiService.getTask(widget.id);
  }

  void _reload() {
    if (!mounted) return;
    final next = ApiService.getTask(widget.id);
    setState(() {
      _future = next;
    });
  }
  String _fmt(dynamic raw) {
    final date = DateTime.tryParse('$raw')?.toLocal();
    if (date == null) {
      return 'Chưa thiết lập';
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
  String _label(String value) => switch (value) {
    'todo' => 'Chưa thực hiện', 'in_progress' => 'Đang thực hiện',
    'completed' => 'Đã hoàn thành', 'high' => 'Cao', 'medium' => 'Trung bình',
    'low' => 'Thấp', _ => value,
  };
  Future<void> _changeStatus(String status) async {
    if (_updating) {
      return;
    }
    setState(() => _updating = true);
    try {
      await ApiService.updateTaskStatus(widget.id, status);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }
  Future<void> _edit() async {
    final result = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => TaskEditScreen(id: widget.id)));
    if (result == true) {
      _reload();
    }
  }
  Future<void> _manage({required bool share, required String title}) async {
    if (share) {
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => TaskShareScreen(taskId: widget.id, taskTitle: title)));
    } else {
      await Navigator.push(context, MaterialPageRoute(
          builder: (_) => TaskAssignScreen(taskId: widget.id, taskTitle: title)));
    }
    _reload();
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8FF),
    appBar: AppBar(title: const Text('Chi tiết công việc'),
      backgroundColor: const Color(0xFF1769E8), foregroundColor: Colors.white,
      actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    body: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Không tải được công việc: ${snapshot.error}', textAlign: TextAlign.center),
          TextButton(onPressed: _reload, child: const Text('Thử lại')),
        ]));
      }
      final task = snapshot.data!;
      final owner = task['isOwner'] == true;
      final canEdit = task['canEdit'] == true || owner;
      final title = '${task['title'] ?? ''}';
      final creator = task['createdBy'];
      final creatorName = creator is Map
          ? '${creator['fullName'] ?? creator['email'] ?? ''}'
          : '${creator ?? ''}';
      final assignees = (task['assigneeIds'] as List? ?? []).whereType<Map>().toList();
      final shares = (task['shares'] as List? ?? []).whereType<Map>().toList();
      final primary = task['primaryAssigneeId'];
      final primaryId = primary is Map ? '${primary['_id']}' : '$primary';
      return ListView(padding: const EdgeInsets.all(18), children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (owner || canEdit)
          Wrap(spacing: 8, children: [
            if (canEdit) OutlinedButton.icon(onPressed: _edit,
              icon: const Icon(Icons.edit), label: const Text('Sửa')),
            if (owner) OutlinedButton.icon(onPressed: () => _manage(share: false, title: title),
              icon: const Icon(Icons.group_add), label: const Text('Giao việc')),
            if (owner) OutlinedButton.icon(onPressed: () => _manage(share: true, title: title),
              icon: const Icon(Icons.share), label: const Text('Chia sẻ')),
          ]),
        const SizedBox(height: 14),
        Card(color: Colors.white, child: Padding(padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mô tả', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6), Text('${task['description'] ?? 'Không có mô tả'}'),
            const Divider(height: 24),
            Text('Người tạo: $creatorName'),
            Text('Trạng thái: ${_label('${task['status'] ?? 'todo'}')}'),
            Text('Ưu tiên: ${_label('${task['priority'] ?? 'medium'}')}'),
            Text('Ngày bắt đầu: ${_fmt(task['startDate'])}'),
            Text('Hạn hoàn thành: ${_fmt(task['dueDate'])}'),
            Text('Ngày tạo: ${_fmt(task['createdAt'])}'),
          ]))),
        if (canEdit) ...[
          const SizedBox(height: 12),
          const Text('Cập nhật trạng thái', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, children: [
            for (final s in ['todo', 'in_progress', 'completed'])
              ChoiceChip(label: Text(_label(s)), selected: task['status'] == s,
                onSelected: _updating ? null : (_) => _changeStatus(s)),
          ]),
        ],
        const SizedBox(height: 16),
        Text('Người được giao (${assignees.length})',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (assignees.isEmpty) const Text('Chưa giao người thực hiện'),
        for (final u in assignees)
          ListTile(dense: true, leading: Icon('${u['_id']}' == primaryId
              ? Icons.star : Icons.person_outline, color: const Color(0xFF1769E8)),
            title: Text('${u['email'] ?? ''}'),
            subtitle: Text('${u['fullName'] ?? ''}')),
        const SizedBox(height: 12),
        Text('Người được chia sẻ (${shares.length})',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (shares.isEmpty) const Text('Chưa chia sẻ công việc cho ai.'),
        for (final share in shares)
          Builder(builder: (context) {
            final user = share['userId'];
            final info = user is Map ? user : <String, dynamic>{};
            final permission = '${share['permission'] ?? 'viewer'}';
            return ListTile(
              dense: true,
              leading: const Icon(Icons.share_outlined, color: Color(0xFF1769E8)),
              title: Text('${info['email'] ?? ''}'),
              subtitle: Text(permission == 'editor' || permission == 'edit'
                ? 'Editor - Được chỉnh sửa' : 'Viewer - Chỉ xem'),
            );
          }),
        const SizedBox(height: 12),
        const Text('Lịch sử hoạt động', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        FutureBuilder<List<Map<String, dynamic>>>(future: ApiService.getTaskActivities(widget.id),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Padding(padding: const EdgeInsets.all(8),
                child: Text(snap.hasError ? 'Không tải được lịch sử.' : 'Đang tải lịch sử...'));
            }
            if (snap.data!.isEmpty) {
              return const Text('Chưa có hoạt động.');
            }
            return Column(children: [for (final a in snap.data!)
              ListTile(dense: true, leading: const Icon(Icons.history),
                title: Text('${a['action'] ?? ''}'),
                subtitle: Text(_fmt(a['createdAt'])))]);
          }),
        if (owner) ...[
          const Divider(height: 24),
          const Text('Nhật ký email', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          FutureBuilder<List<Map<String, dynamic>>>(future: ApiService.getTaskEmailLogs(widget.id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Text(snap.hasError ? 'Không tải được nhật ký email.' : 'Đang tải...');
              }
              if (snap.data!.isEmpty) {
                return const Text('Chưa có yêu cầu gửi email.');
              }
              return Column(children: [for (final e in snap.data!)
                ListTile(dense: true, leading: const Icon(Icons.mail_outline),
                  title: Text('${e['recipientEmail'] ?? ''}'),
                  subtitle: Text('Trạng thái: ${e['status'] ?? ''}'))]);
            }),
        ],
      ]);
    }),
  );
}
