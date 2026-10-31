import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'task_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool hide = true;
  @override
  void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (!formKey.currentState!.validate() || busy) return;
    setState(() => busy = true);
    try {
      await ApiService.login(email.text, password.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const TaskListScreen()), (_) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.task_alt, size: 80, color: Color(0xFF2563EB)),
        const SizedBox(height: 18),
        const Text('Task Manager', textAlign: TextAlign.center, style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Đăng nhập để quản lý công việc', textAlign: TextAlign.center),
        const SizedBox(height: 30),
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), validator: (v) => (v == null || !v.contains('@')) ? 'Nhập email hợp lệ' : null),
        const SizedBox(height: 16),
        TextFormField(controller: password, obscureText: hide, decoration: InputDecoration(labelText: 'Mật khẩu', border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => hide = !hide), icon: Icon(hide ? Icons.visibility : Icons.visibility_off))), validator: (v) => (v == null || v.isEmpty) ? 'Nhập mật khẩu' : null),
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.all(14), child: Text(busy ? 'Đang đăng nhập...' : 'Đăng nhập'))),
        TextButton(onPressed: busy ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), child: const Text('Chưa có tài khoản? Đăng ký')),
      ])),
    )))),
  );
}
