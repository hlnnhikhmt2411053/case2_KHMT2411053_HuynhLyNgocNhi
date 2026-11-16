import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _oldPassword = TextEditingController();
  final _newPassword = TextEditingController();
  late Future<Map<String, dynamic>> _profile;
  bool _saving = false;
  @override
  void initState() { super.initState(); _profile = ApiService.getMe(); }
  void _refresh() {
    if (!mounted) return;
    final next = ApiService.getMe();
    setState(() {
      _profile = next;
    });
  }
  Future<void> _saveName() async {
    if (_saving || _name.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.updateMe(_name.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
  Future<void> _changePassword() async {
    if (_saving) {
      return;
    }
    if (_newPassword.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu mới ít nhất 8 ký tự.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.changePassword(_oldPassword.text, _newPassword.text);
      _oldPassword.clear(); _newPassword.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không đổi được mật khẩu: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
  @override
  void dispose() { _name.dispose(); _oldPassword.dispose(); _newPassword.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F8FF),
    appBar: AppBar(title: const Text('Tài khoản của tôi'),
      backgroundColor: const Color(0xFF1769E8), foregroundColor: Colors.white),
    body: FutureBuilder<Map<String, dynamic>>(future: _profile, builder: (context, snap) {
      if (!snap.hasData) {
        return Center(child: snap.hasError ?
          Text('Lỗi: ${snap.error}') : const CircularProgressIndicator());
      }
      final user = snap.data!;
      if (_name.text.isEmpty) {
        _name.text = (user['fullName'] ?? '').toString();
      }
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.account_circle_outlined, size: 72, color: Color(0xFF1769E8)),
        const SizedBox(height: 12),
        Text('${user['email'] ?? ''}', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        const Text('Cập nhật thông tin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Họ và tên',
          border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saving ? null : _saveName, child: const Text('Lưu hồ sơ')),
        const Divider(height: 36),
        const Text('Đổi mật khẩu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(controller: _oldPassword, obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: _newPassword, obscureText: true,
          decoration: const InputDecoration(labelText: 'Mật khẩu mới (ít nhất 8 ký tự)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saving ? null : _changePassword,
          child: const Text('Đổi mật khẩu')),
      ]);
    }),
  );
}
