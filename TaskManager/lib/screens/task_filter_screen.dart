import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Kết quả chọn bộ lọc: chỉ chứa giá trị, không giữ BuildContext hay controller.
class TaskFilterResult {
  final String query;
  final String assigneeEmail;
  final String assigneeId;
  final String status;
  final String priority;
  final String scope;
  final String sortBy;

  const TaskFilterResult({
    required this.query,
    required this.assigneeEmail,
    required this.assigneeId,
    required this.status,
    required this.priority,
    required this.scope,
    required this.sortBy,
  });
}

/// Màn hình riêng để tránh lỗi vòng đời widget khi mở bộ lọc trong dialog.
class TaskFilterScreen extends StatefulWidget {
  final TaskFilterResult initial;

  const TaskFilterScreen({super.key, required this.initial});

  @override
  State<TaskFilterScreen> createState() => _TaskFilterScreenState();
}

class _TaskFilterScreenState extends State<TaskFilterScreen> {
  late final TextEditingController _search;
  late final TextEditingController _assigneeEmail;
  late String _scope;
  late String _status;
  late String _priority;
  late String _sortBy;
  bool _applying = false;

  static const _blue = Color(0xFF1769E8);

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initial.query);
    _assigneeEmail = TextEditingController(text: widget.initial.assigneeEmail);
    _scope = widget.initial.scope;
    _status = widget.initial.status;
    _priority = widget.initial.priority;
    _sortBy = widget.initial.sortBy;
  }

  @override
  void dispose() {
    _search.dispose();
    _assigneeEmail.dispose();
    super.dispose();
  }

  void _reset() {
    FocusScope.of(context).unfocus();
    _search.clear();
    _assigneeEmail.clear();
    setState(() {
      _scope = 'all';
      _status = '';
      _priority = '';
      _sortBy = 'createdAt';
    });
  }

  Future<void> _apply() async {
    if (_applying) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _applying = true;
    });

    final email = _assigneeEmail.text.trim().toLowerCase();
    String assigneeId = '';
    try {
      if (email.isNotEmpty) {
        final users = await ApiService.searchUsers(email);
        final matches = users.where(
          (user) => (user['email'] ?? '').toString().toLowerCase() == email,
        );
        if (matches.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy email người được giao đã đăng ký.'),
            ),
          );
          return;
        }
        assigneeId = (matches.first['_id'] ?? '').toString();
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        TaskFilterResult(
          query: _search.text.trim(),
          assigneeEmail: email,
          assigneeId: assigneeId,
          scope: _scope,
          status: _status,
          priority: _priority,
          sortBy: _sortBy,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không áp dụng được bộ lọc: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _applying = false;
        });
      }
    }
  }

  Widget _select({
    required String label,
    required String value,
    required List<MapEntry<String, String>> options,
    required ValueChanged<String> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: options
              .map((option) => DropdownMenuItem<String>(
                    value: option.key,
                    child: Text(option.value),
                  ))
              .toList(),
          onChanged: _applying
              ? null
              : (next) {
                  if (next != null) onChanged(next);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Tìm kiếm và lọc'),
        backgroundColor: _blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Tìm theo tên công việc',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _assigneeEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email người được giao (tùy chọn)',
                prefixIcon: Icon(Icons.person_search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            _select(
              label: 'Loại công việc',
              value: _scope,
              options: const [
                MapEntry('all', 'Tất cả'),
                MapEntry('created', 'Tôi tạo'),
                MapEntry('assigned', 'Được giao'),
                MapEntry('shared', 'Được chia sẻ'),
              ],
              onChanged: (value) => setState(() => _scope = value),
            ),
            const SizedBox(height: 14),
            _select(
              label: 'Trạng thái',
              value: _status,
              options: const [
                MapEntry('', 'Tất cả'),
                MapEntry('todo', 'Chưa thực hiện'),
                MapEntry('in_progress', 'Đang thực hiện'),
                MapEntry('completed', 'Đã hoàn thành'),
              ],
              onChanged: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 14),
            _select(
              label: 'Độ ưu tiên',
              value: _priority,
              options: const [
                MapEntry('', 'Tất cả'),
                MapEntry('low', 'Thấp'),
                MapEntry('medium', 'Trung bình'),
                MapEntry('high', 'Cao'),
              ],
              onChanged: (value) => setState(() => _priority = value),
            ),
            const SizedBox(height: 14),
            _select(
              label: 'Sắp xếp theo',
              value: _sortBy,
              options: const [
                MapEntry('createdAt', 'Thời gian tạo'),
                MapEntry('dueDate', 'Hạn hoàn thành'),
                MapEntry('priority', 'Độ ưu tiên'),
              ],
              onChanged: (value) => setState(() => _sortBy = value),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _applying ? null : _reset,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Đặt lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _applying ? null : _apply,
                    style: FilledButton.styleFrom(backgroundColor: _blue),
                    icon: _applying
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Áp dụng'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
