import 'package:flutter/material.dart';
import 'task_assign_screen.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'task_detail_screen.dart';
import 'task_create_screen.dart';
import 'task_edit_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late Future<List<Map<String, dynamic>>> future;
  String? _deletingTaskId;

  @override
  void initState() {
    super.initState();
    future = ApiService.getTasks();
  }

  // LAM MOI DANH SACH
  void reload() {
    setState(() {
      future = ApiService.getTasks();
    });
  }

  // BUOI 2: THEM CONG VIEC
  Future<void> openCreateTask() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const TaskCreateScreen(),
      ),
    );

    if (!mounted) return;

    if (created == true) {
      reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thêm công việc thành công!'),
        ),
      );
    }
  }

  // BUOI 2: SUA CONG VIEC
  Future<void> openEditTask(
      Map<String, dynamic> task,
      ) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(
          id: task['_id'].toString(),
        ),
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật công việc thành công!'),
        ),
      );
    }
  }

  // BUOI 2: XOA CONG VIEC
  Future<void> deleteTask(
      Map<String, dynamic> task,
      ) async {
    if (_deletingTaskId != null) return;

    final id = task['_id'].toString();
    final title = (task['title'] ?? 'công việc này').toString();

    // HOP THOAI XAC NHAN
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text(
            'Bạn có chắc muốn xóa công việc "$title" không?\n\n'
                'Hành động này không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text(
                'Xóa',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _deletingTaskId = id;
    });

    try {
      // GOI API DELETE
      await ApiService.deleteTask(id);

      if (!mounted) return;

      // TAI LAI DANH SACH
      reload();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xóa công việc thành công!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xóa công việc: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingTaskId = null;
        });
      }
    }
  }

  // BUOI 2: GIAO CONG VIEC
  Future<void> openAssignTask(Map<String, dynamic> task) async {
    if (_deletingTaskId != null) return;

    final assigned = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TaskAssignScreen(
          taskId: task['_id'].toString(),
          taskTitle: (task['title'] ?? '').toString(),
        ),
      ),
    );

    if (!mounted) return;

    if (assigned == true) {
      reload();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giao công việc thành công!')),
      );
    }
  }

  // DANG XUAT
  Future<void> logout() async {
    await ApiService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
          (_) => false,
    );
  }

  // TEN TRANG THAI
  String status(String? value) {
    switch (value) {
      case 'completed':
        return 'Đã hoàn thành';
      case 'in_progress':
        return 'Đang thực hiện';
      default:
        return 'Chưa thực hiện';
    }
  }

  // TEN MUC DO UU TIEN
  String priority(String? value) {
    switch (value) {
      case 'high':
        return 'Cao';
      case 'low':
        return 'Thấp';
      default:
        return 'Trung bình';
    }
  }

  // XEM CHI TIET CONG VIEC
  Future<void> openTask(
      Map<String, dynamic> task,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          id: task['_id'].toString(),
        ),
      ),
    );

    if (!mounted) return;
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),

      appBar: AppBar(
        title: const Text(
          'Danh sách công việc',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      // NUT THEM CONG VIEC
      floatingActionButton: FloatingActionButton(
        onPressed: openCreateTask,
        backgroundColor: const Color(0xFF1769E8),
        foregroundColor: Colors.white,
        tooltip: 'Thêm công việc',
        child: const Icon(Icons.add),
      ),

      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Không tải được công việc: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: reload,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có công việc nào.\n'
                    'Nhấn dấu + để thêm công việc mới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final next = ApiService.getTasks();

              setState(() {
                future = next;
              });

              await next;
            },

            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,

              separatorBuilder: (context, index) {
                return const SizedBox(height: 10);
              },

              itemBuilder: (context, index) {
                final task = tasks[index];
                final taskId = task['_id'].toString();
                final isDeleting = _deletingTaskId == taskId;
                final isOwner = task['isOwner'] == true;
                // API danh sách đã populate email người được giao.
                final rawAssignees = task['assigneeIds'];
                final assignees = rawAssignees is List
                    ? rawAssignees.whereType<Map>().toList()
                    : <Map>[];
                final primary = task['primaryAssigneeId'];
                final primaryId = primary is Map
                    ? primary['_id']?.toString()
                    : primary?.toString();

                return Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),

                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),

                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F0FF),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: Color(0xFF1769E8),
                      ),
                    ),

                    title: Text(
                      '${task['title'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${status(task['status']?.toString())}'
                                ' • Ưu tiên: '
                                '${priority(task['priority']?.toString())}',
                          ),
                          if (assignees.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.group_outlined,
                                    size: 16, color: Color(0xFF1769E8)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Người được giao (${assignees.length})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1769E8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            for (final user in assignees)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (user['_id']?.toString() == primaryId)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.star,
                                            size: 14, color: Colors.amber),
                                      ),
                                    Expanded(
                                      child: Text(
                                        (user['email'] ?? '').toString(),
                                        style: const TextStyle(fontSize: 12),
                                        softWrap: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),

                    // MENU GIAO VIEC, SUA, XOA (khong tran man hinh)
                    trailing: isOwner
                        ? PopupMenuButton<String>(
                      tooltip: 'Tùy chọn công việc',
                      enabled: _deletingTaskId == null,
                      icon: isDeleting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'assign') {
                          openAssignTask(task);
                        } else if (value == 'edit') {
                          openEditTask(task);
                        } else if (value == 'delete') {
                          deleteTask(task);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'assign',
                          child: Row(
                            children: [
                              Icon(Icons.group_add_outlined),
                              SizedBox(width: 12),
                              Text('Giao công việc'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined),
                              SizedBox(width: 12),
                              Text('Sửa công việc'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.red),
                              SizedBox(width: 12),
                              Text('Xóa công việc'),
                            ],
                          ),
                        ),
                      ],
                    )
                        : const Icon(
                      Icons.visibility_outlined,
                      color: Colors.grey,
                    ),

                    onTap: () => openTask(task),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
