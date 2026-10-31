import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/task_list_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await ApiService.getToken();
  runApp(TaskManagerApp(signedIn: token != null));
}

class TaskManagerApp extends StatelessWidget {
  final bool signedIn;
  const TaskManagerApp({super.key, required this.signedIn});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Task Manager',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)), scaffoldBackgroundColor: const Color(0xFFF6F8FC)),
    home: signedIn ? const TaskListScreen() : const LoginScreen(),
  );
}
