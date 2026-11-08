
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskEditScreen extends StatefulWidget {
  final String id;

  const TaskEditScreen({
    super.key,
    required this.id,
  });

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  String _status = 'todo';

  DateTime? _startDate;
  DateTime? _dueDate;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTask();
  }

  // Đọc ngày từ MongoDB
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString())?.toLocal();
  }

  // Hiển thị ngày theo định dạng dd/MM/yyyy
  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa chọn ngày';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // Lấy thông tin công việc cũ
  Future<void> _loadTask() async {
    try {
      final task = await ApiService.getTask(widget.id);

      if (!mounted) return;

      setState(() {
        _titleController.text =
            (task['title'] ?? '').toString();

        _descriptionController.text =
            (task['description'] ?? '').toString();

        final priority = task['priority']?.toString();

        _priority = ['low', 'medium', 'high'].contains(priority)
            ? priority!
            : 'medium';

        final status = task['status']?.toString();

        _status = ['todo', 'in_progress', 'completed']
            .contains(status)
            ? status!
            : 'todo';

        _startDate = _parseDate(task['startDate']);
        _dueDate = _parseDate(task['dueDate']);

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // Chọn ngày
  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_dueDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  // Lưu thông tin đã chỉnh sửa
  Future<void> _saveTask() async {
    if (_saving || !_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate != null &&
        _dueDate != null &&
        _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hạn hoàn thành không được trước ngày bắt đầu',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await ApiService.updateTask(
        id: widget.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        status: _status,
        startDate: _startDate,
        dueDate: _dueDate,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể sửa công việc: $e'),
        ),
      );
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),

      appBar: AppBar(
        title: const Text(
          'Sửa công việc',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
      ),

      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Không tải được công việc:\n$_error',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Chỉnh sửa thông tin công việc',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B2B49),
              ),
            ),

            const SizedBox(height: 20),

            // Tên công việc
            TextFormField(
              controller: _titleController,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Tên công việc',
                prefixIcon: Icon(Icons.task_alt),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Vui lòng nhập tên công việc';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Mô tả
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 5000,
              decoration: const InputDecoration(
                labelText: 'Mô tả công việc',
                prefixIcon:
                Icon(Icons.description_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            // Mức độ ưu tiên
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Mức độ ưu tiên',
                prefixIcon: Icon(Icons.flag_outlined),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'low',
                  child: Text('Thấp'),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: Text('Trung bình'),
                ),
                DropdownMenuItem(
                  value: 'high',
                  child: Text('Cao'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _priority = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Trạng thái
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Trạng thái công việc',
                prefixIcon: Icon(Icons.pending_actions),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'todo',
                  child: Text('Chưa thực hiện'),
                ),
                DropdownMenuItem(
                  value: 'in_progress',
                  child: Text('Đang thực hiện'),
                ),
                DropdownMenuItem(
                  value: 'completed',
                  child: Text('Đã hoàn thành'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            // Ngày bắt đầu
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF1769E8),
                ),
                title: const Text('Ngày bắt đầu'),
                subtitle: Text(_formatDate(_startDate)),
                onTap: () => _pickDate(true),
                trailing: IconButton(
                  tooltip: 'Bỏ ngày bắt đầu',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Hạn hoàn thành
            Card(
              color: Colors.white,
              child: ListTile(
                leading: const Icon(
                  Icons.event_available,
                  color: Color(0xFF1769E8),
                ),
                title: const Text('Hạn hoàn thành'),
                subtitle: Text(_formatDate(_dueDate)),
                onTap: () => _pickDate(false),
                trailing: IconButton(
                  tooltip: 'Bỏ hạn hoàn thành',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _dueDate = null;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Nút lưu thay đổi
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveTask,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save),
                label: Text(
                  _saving
                      ? 'Đang lưu...'
                      : 'Lưu thay đổi',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  const Color(0xFF1769E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
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
