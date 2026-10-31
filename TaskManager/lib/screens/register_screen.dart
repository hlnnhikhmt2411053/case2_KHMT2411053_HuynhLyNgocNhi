import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'task_list_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final keyForm = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  @override
  void dispose() { name.dispose(); email.dispose(); password.dispose(); confirm.dispose(); super.dispose(); }
  Future<void> submit() async {
    if (!keyForm.currentState!.validate() || busy) return;
    setState(() => busy = true);
    try {
      await ApiService.register(name.text, email.text, password.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const TaskListScreen()), (_) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đăng ký tài khoản')),
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440), child: Form(key: keyForm, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.person_add_alt_1, color: Color(0xFF2563EB), size: 68),
        const SizedBox(height: 20),
        TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder()), validator: (v) => (v ?? '').trim().isEmpty ? 'Nhập họ tên' : null),
        const SizedBox(height: 12),
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()), validator: (v) => !(v ?? '').contains('@') ? 'Nhập email hợp lệ' : null),
        const SizedBox(height: 12),
        TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu (ít nhất 8 ký tự)', border: OutlineInputBorder()), validator: (v) => (v ?? '').length < 8 ? 'Mật khẩu phải có ít nhất 8 ký tự' : null),
        const SizedBox(height: 12),
        TextFormField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu', border: OutlineInputBorder()), validator: (v) => v != password.text ? 'Mật khẩu xác nhận không khớp' : null),
        const SizedBox(height: 20),
        FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.all(14), child: Text(busy ? 'Đang tạo tài khoản...' : 'Đăng ký'))),
      ])),
    )))),
  );
}
