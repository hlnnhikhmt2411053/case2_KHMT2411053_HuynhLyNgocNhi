
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TaskCreateScreen extends StatefulWidget {
  const TaskCreateScreen({super.key});

  @override
  State<TaskCreateScreen> createState() =>
      _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  String _status = 'todo';

  DateTime? _startDate;
  DateTime? _dueDate;

  bool _saving = false;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chưa chọn ngày';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _pickDate(bool isStartDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_dueDate ?? _startDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (isStartDate) {
        _startDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

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
      await ApiService.createTask(
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
          content: Text('Không thể thêm công việc: $e'),
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
          'Thêm công việc',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Thông tin công việc',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B2B49),
                ),
              ),

              const SizedBox(height: 22),

              // TEN CONG VIEC
              TextFormField(
                controller: _titleController,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Tên công việc',
                  hintText: 'Nhập tên công việc',
                  prefixIcon: Icon(Icons.task_alt),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên công việc';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // MO TA
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 5000,
                decoration: const InputDecoration(
                  labelText: 'Mô tả công việc',
                  hintText: 'Nhập mô tả công việc',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 14),

              // MUC DO UU TIEN
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Mức độ ưu tiên',
                  prefixIcon: Icon(Icons.flag_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
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

              const SizedBox(height: 20),

              // TRANG THAI
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Trạng thái công việc',
                  prefixIcon: Icon(Icons.pending_actions),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
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

              const SizedBox(height: 20),

              // NGAY BAT DAU
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF1769E8),
                  ),
                  title: const Text('Ngày bắt đầu'),
                  subtitle: Text(_formatDate(_startDate)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickDate(true),
                ),
              ),

              const SizedBox(height: 12),

              // HAN HOAN THANH
              Card(
                color: Colors.white,
                child: ListTile(
                  leading: const Icon(
                    Icons.event_available,
                    color: Color(0xFF1769E8),
                  ),
                  title: const Text('Hạn hoàn thành'),
                  subtitle: Text(_formatDate(_dueDate)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickDate(false),
                ),
              ),

              const SizedBox(height: 28),

              // NUT LUU
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
                        : 'Lưu công việc',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
      ),
    );
  }
}
