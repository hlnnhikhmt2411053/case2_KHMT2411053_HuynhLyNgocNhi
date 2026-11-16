import 'package:flutter/material.dart';
import '../services/api_service.dart';

// Một form dùng chung cho Thêm và Sửa, giúp hai chức năng nhất quán.
class TaskFormScreen extends StatefulWidget {
  final String? taskId;
  const TaskFormScreen({super.key, this.taskId});
  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  String _priority = 'medium';
  String _status = 'todo';
  DateTime? _start;
  DateTime? _due;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get editing => widget.taskId != null;
  @override
  void initState() {
    super.initState();
    if (editing) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final task = await ApiService.getTask(widget.taskId!);
      if (!mounted) return;
      setState(() {
        _title.text = (task['title'] ?? '').toString();
        _description.text = (task['description'] ?? '').toString();
        _priority = (task['priority'] ?? 'medium').toString();
        _status = (task['status'] ?? 'todo').toString();
        _start =
            DateTime.tryParse((task['startDate'] ?? '').toString())?.toLocal();
        _due = DateTime.tryParse((task['dueDate'] ?? '').toString())?.toLocal();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _datePicker({required bool start}) async {
    final initial = (start ? _start : _due) ?? DateTime.now();
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (date == null || !mounted) return;
    setState(() {
      if (start) {
        _start = date;
      } else {
        _due = date;
      }
    });
  }

  String _dateText(DateTime? d) => d == null
      ? 'Chưa chọn'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    if (_start != null && _due != null && _due!.isBefore(_start!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Hạn hoàn thành không được trước ngày bắt đầu.')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (editing) {
        await ApiService.updateTask(
            id: widget.taskId!,
            title: _title.text,
            description: _description.text,
            priority: _priority,
            status: _status,
            startDate: _start,
            dueDate: _due);
      } else {
        await ApiService.createTask(
            title: _title.text,
            description: _description.text,
            priority: _priority,
            status: _status,
            startDate: _start,
            dueDate: _due);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể lưu: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1769E8);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
          title: Text(editing ? 'Sửa công việc' : 'Thêm công việc'),
          backgroundColor: blue,
          foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Lỗi: $_error'),
                  TextButton(onPressed: _load, child: const Text('Thử lại'))
                ]))
              : Form(
                  key: _key,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    TextFormField(
                        controller: _title,
                        maxLength: 200,
                        decoration: const InputDecoration(
                            labelText: 'Tên công việc *',
                            prefixIcon: Icon(Icons.task_alt),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Nhập tên công việc'
                            : null),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _description,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 5000,
                        decoration: const InputDecoration(
                            labelText: 'Mô tả',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: _priority,
                        decoration: const InputDecoration(
                            labelText: 'Mức độ ưu tiên',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Thấp')),
                          DropdownMenuItem(
                              value: 'medium', child: Text('Trung bình')),
                          DropdownMenuItem(value: 'high', child: Text('Cao')),
                        ],
                        onChanged: (v) =>
                            setState(() => _priority = v ?? 'medium')),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(
                            labelText: 'Trạng thái',
                            border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(
                              value: 'todo', child: Text('Chưa thực hiện')),
                          DropdownMenuItem(
                              value: 'in_progress',
                              child: Text('Đang thực hiện')),
                          DropdownMenuItem(
                              value: 'completed', child: Text('Đã hoàn thành')),
                        ],
                        onChanged: (v) =>
                            setState(() => _status = v ?? 'todo')),
                    const SizedBox(height: 16),
                    Card(
                        color: Colors.white,
                        child: Column(children: [
                          ListTile(
                              title: const Text('Ngày bắt đầu'),
                              subtitle: Text(_dateText(_start)),
                              leading: const Icon(Icons.calendar_month),
                              onTap: () => _datePicker(start: true),
                              trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _start = null))),
                          const Divider(height: 1),
                          ListTile(
                              title: const Text('Hạn hoàn thành'),
                              subtitle: Text(_dateText(_due)),
                              leading: const Icon(Icons.event),
                              onTap: () => _datePicker(start: false),
                              trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _due = null))),
                        ])),
                    const SizedBox(height: 22),
                    SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.save_outlined),
                            label: Text(_saving
                                ? 'Đang lưu...'
                                : (editing
                                    ? 'Lưu thay đổi'
                                    : 'Thêm công việc')))),
                  ])),
    );
  }
}
