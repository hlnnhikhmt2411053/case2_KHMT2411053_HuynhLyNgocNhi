import 'package:flutter/material.dart';
import 'task_form_screen.dart';
class TaskEditScreen extends StatelessWidget {
  final String id;
  const TaskEditScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) => TaskFormScreen(taskId: id);
}
