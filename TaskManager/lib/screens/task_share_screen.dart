import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskShareScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const TaskShareScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<TaskShareScreen> createState() => _TaskShareScreenState();
}

class _TaskShareScreenState extends State<TaskShareScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> _shares = [];
  String _permission = 'viewer';
  bool _loading = true;
  bool _saving = false;
  String? _removingUserId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadShares();
  }

  Future<void> _loadShares() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await ApiService.getTaskShares(taskId: widget.taskId);
      final raw = result['shares'];
      if (raw is! List) throw Exception('Danh sách chia sẻ không hợp lệ.');
      if (!mounted) return;
      setState(() {
        _shares = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _share() async {
    if (_saving || _loading || _removingUserId != null) return;
    if (!_formKey.currentState!.validate()) return;
    final emails = _emailController.text.split(RegExp(r'[,;\n]+'))
        .map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet().toList();
    if (emails.isEmpty || emails.length > 50) {
      _notify('Vui lòng nhập từ 1 đến 50 email.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.shareTaskMultiple(
        taskId: widget.taskId,
        emails: emails,
        permission: _permission,
      );
      if (!mounted) return;
      _emailController.clear();
      _notify('Chia sẻ công việc thành công!');
      await _loadShares();
    } catch (e) {
      _notify('Không thể chia sẻ: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revoke(String shareId, String email) async {
    if (_saving || _removingUserId != null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thu hồi quyền chia sẻ?'),
        content: Text('Ngừng chia sẻ công việc cho $email?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Thu hồi', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removingUserId = shareId);
    try {
      await ApiService.revokeTaskShare(taskId: widget.taskId, shareId: shareId);
      if (!mounted) return;
      _notify('Đã thu hồi quyền chia sẻ.');
      await _loadShares();
    } catch (e) {
      _notify('Không thể thu hồi: $e');
    } finally {
      if (mounted) setState(() => _removingUserId = null);
    }
  }

  Future<void> _changePermission(String shareId, String nextPermission) async {
    if (_loading || _saving || _removingUserId != null) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateSharePermission(widget.taskId, shareId, nextPermission);
      if (!mounted) return;
      _notify('Đã cập nhật quyền chia sẻ.');
      await _loadShares();
    } catch (e) {
      _notify('Không cập nhật được quyền: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1769E8);
    final busy = _loading || _saving || _removingUserId != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Chia sẻ công việc',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Công việc cần chia sẻ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(Icons.assignment_outlined, color: blue),
                title: Text(widget.taskTitle),
              ),
            ),
            const SizedBox(height: 22),
            const Text('Chia sẻ bằng email',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _emailController,
                enabled: !busy && _loadError == null,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _share(),
                decoration: const InputDecoration(
                  labelText: 'Email người nhận (có thể nhập nhiều)',
                  hintText: 'a@example.com, b@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final emails = (value ?? '').split(RegExp(r'[,;\n]+'))
                      .map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                  final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                  if (emails.isEmpty || emails.length > 50 ||
                      emails.any((e) => e.length > 254 || !valid.hasMatch(e))) {
                    return 'Nhập từ 1 đến 50 email hợp lệ, phân cách bằng dấu phẩy.';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _permission,
              decoration: const InputDecoration(
                labelText: 'Quyền truy cập',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'viewer', child: Text('Viewer - Chỉ xem')),
                DropdownMenuItem(value: 'editor', child: Text('Editor - Chỉnh sửa')),
              ],
              onChanged: busy || _loadError != null
                  ? null
                  : (value) => setState(() => _permission = value ?? 'viewer'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Email phải có tài khoản TaskManager. Có thể chia sẻ nhiều người bằng dấu phẩy; chọn quyền viewer/editor.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: busy || _loadError != null ? null : _share,
                icon: _saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_outlined),
                label: Text(_saving ? 'Đang chia sẻ...' : 'Chia sẻ công việc'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Đã chia sẻ (${_shares.length})',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_loadError != null)
              Column(
                children: [
                  Text('Không tải được danh sách chia sẻ: $_loadError',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _loadShares,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  ),
                ],
              )
            else if (_shares.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa chia sẻ công việc cho ai.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              for (final share in _shares)
                Builder(builder: (context) {
                  final user = share['userId'];
                  final info = user is Map ? user : <String, dynamic>{};
                  final shareId = (share['_id'] ?? '').toString();
                  final email = (info['email'] ?? 'Không rõ email').toString();
                  final permission = share['permission']?.toString() ?? 'viewer';
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE8F0FF),
                        child: Icon(Icons.person_outline, color: blue),
                      ),
                      title: Text(email, overflow: TextOverflow.ellipsis),
                      subtitle: DropdownButton<String>(
                        value: permission == 'editor' || permission == 'edit' ? 'editor' : 'viewer',
                        isDense: true,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'viewer', child: Text('Viewer - Chỉ xem')),
                          DropdownMenuItem(value: 'editor', child: Text('Editor - Được sửa')),
                        ],
                        onChanged: busy || shareId.isEmpty ? null : (value) {
                          if (value != null && value != permission) {
                            _changePermission(shareId, value);
                          }
                        },
                      ),
                      trailing: IconButton(
                        tooltip: 'Thu hồi quyền',
                        icon: _removingUserId == shareId
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.person_remove_outlined, color: Colors.red),
                        onPressed: busy || shareId.isEmpty ? null : () => _revoke(shareId, email),
                      ),
                    ),
                  );
                }),
          ],
        ),
      ),
    );
  }
}
