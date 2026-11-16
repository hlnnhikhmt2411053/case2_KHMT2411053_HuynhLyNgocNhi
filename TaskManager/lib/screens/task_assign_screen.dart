import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskAssignScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;

  const TaskAssignScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
  });

  @override
  State<TaskAssignScreen> createState() => _TaskAssignScreenState();
}

class _TaskAssignScreenState extends State<TaskAssignScreen> {
  final TextEditingController _emailController = TextEditingController();
  final List<String> _emails = [];

  String? _primaryEmail;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAssignees();
  }

  // Lấy danh sách người đã được giao từ MongoDB thông qua backend.
  Future<void> _loadAssignees() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final result = await ApiService.getTaskAssignees(
        taskId: widget.taskId,
      );

      final rawAssignees = result['assignees'];
      if (rawAssignees is! List) {
        throw const FormatException('Danh sách người nhận không hợp lệ.');
      }

      final loadedEmails = <String>[];
      for (final item in rawAssignees) {
        if (item is! Map) continue;
        final rawEmail = item['email'];
        if (rawEmail is! String) continue;
        final email = rawEmail.trim().toLowerCase();
        if (email.isNotEmpty && !loadedEmails.contains(email)) {
          loadedEmails.add(email);
        }
      }

      final rawPrimary = result['primaryEmail'];
      final primary = rawPrimary is String
          ? rawPrimary.trim().toLowerCase()
          : null;

      if (!mounted) return;
      setState(() {
        _emails
          ..clear()
          ..addAll(loadedEmails);
        _primaryEmail = loadedEmails.contains(primary) ? primary : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  // Tim tai khoan theo ten/email ngay tren giao dien giao viec (yeu cau de).
  Future<void> _searchUser() async {
    final q = _emailController.text.trim();
    if (q.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhap it nhat 2 ky tu de tim ten/email.')),
      );
      return;
    }
    try {
      final users = await ApiService.searchUsers(q);
      if (!mounted) return;
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (bottomContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Chon tai khoan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (users.isEmpty) const Padding(
                padding: EdgeInsets.all(16), child: Text('Khong tim thay tai khoan phu hop.'),
              ),
              ...users.take(15).map((user) => ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text('${user['fullName'] ?? ''}'),
                subtitle: Text('${user['email'] ?? ''}'),
                onTap: () => Navigator.pop(bottomContext, '${user['email'] ?? ''}'),
              )),
            ]),
          ),
        ),
      );
      if (!mounted || selected == null || selected.isEmpty) return;
      _emailController.text = selected;
      _addEmail();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Loi tim tai khoan: $e')));
    }
  }

  void _addEmail() {
    if (_loading || _saving) return;
    final email = _emailController.text.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập email hợp lệ.')),
      );
      return;
    }

    if (_emails.contains(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email này đã có trong danh sách.')),
      );
      return;
    }

    if (_emails.length >= 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chỉ được giao tối đa 50 người.')),
      );
      return;
    }

    setState(() {
      _emails.add(email);
      _primaryEmail ??= email;
      _emailController.clear();
    });
  }

  void _removeEmail(String email) {
    if (_loading || _saving) return;
    setState(() {
      _emails.remove(email);
      if (_primaryEmail == email) {
        _primaryEmail = _emails.isEmpty ? null : _emails.first;
      }
    });
  }

  Future<void> _saveAssignment() async {
    if (_loading || _saving || _loadError != null) return;

    if (_emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất một người nhận.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.assignTask(
        taskId: widget.taskId,
        emails: List<String>.from(_emails),
        primaryEmail: _primaryEmail,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể giao công việc: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text(
          'Giao công việc',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          const Text('Không tải được danh sách người nhận.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_loadError!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadAssignees,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Công việc cần giao',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        color: Colors.white,
                        child: ListTile(
                          leading: const Icon(
                            Icons.assignment_outlined,
                            color: Color(0xFF1769E8),
                          ),
                          title: Text(widget.taskTitle),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Thêm người nhận theo tên hoặc email',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _emailController,
                        enabled: !_saving,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addEmail(),
                        decoration: const InputDecoration(
                          labelText: 'Email người nhận',
                          hintText: 'email@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _searchUser,
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Tìm tài khoản theo tên / email'),
                      ),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _addEmail,
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Thêm người nhận'),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Danh sách người nhận (${_emails.length})',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      if (_emails.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Chưa có người nhận nào.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      for (final email in _emails)
                        Card(
                          color: Colors.white,
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE8F0FF),
                              child: Icon(
                                Icons.person_outline,
                                color: Color(0xFF1769E8),
                              ),
                            ),
                            title: Text(
                              email,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              _primaryEmail == email
                                  ? 'Người phụ trách chính'
                                  : 'Người được giao',
                            ),
                            trailing: IconButton(
                              tooltip: 'Bỏ người nhận',
                              onPressed: _saving
                                  ? null
                                  : () => _removeEmail(email),
                              icon: const Icon(Icons.close, color: Colors.red),
                            ),
                          ),
                        ),
                      if (_emails.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Người phụ trách chính',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_primaryEmail),
                          initialValue: _primaryEmail,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.star_outline),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _emails.map((email) {
                            return DropdownMenuItem<String>(
                              value: email,
                              child: Text(
                                email,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() => _primaryEmail = value);
                                },
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Lưu ý: Người nhận phải có tài khoản '
                        'đã đăng ký trong hệ thống.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveAssignment,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _saving
                                ? 'Đang giao công việc...'
                                : 'Giao công việc',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1769E8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
