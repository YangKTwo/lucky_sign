import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final path = _registerMode ? '/api/auth/register' : '/api/auth/login';
      final body = <String, dynamic>{
        'email': _email.text.trim(),
        'password': _password.text,
        if (_registerMode) 'nickname': _nickname.text.trim(),
      };
      final res = await ApiClient.instance.postJson(path, body);
      final token = res['data']['token'] as String;
      await ApiClient.instance.saveToken(token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE4C4), Color(0xFFFFF8F0), Color(0xFFF3E6D8)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            children: [
              const SizedBox(height: 12),
              const Text('🍀', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                '今日幸运签',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              Text(
                _registerMode ? '注册后自动进入小圈子' : '每天一签，完成任务攒积分',
                style: const TextStyle(fontSize: 15, color: Color(0xFF7A7068)),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 8))],
                ),
                child: Column(
                  children: [
                    if (_registerMode) ...[
                      TextField(
                        controller: _nickname,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: '昵称', prefixIcon: Icon(Icons.person_outline)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: '邮箱', prefixIcon: Icon(Icons.mail_outline)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: Text(_loading ? '请稍候…' : (_registerMode ? '加入圈子' : '进入今日')),
                      ),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _registerMode = !_registerMode;
                                _error = null;
                              }),
                      child: Text(_registerMode ? '已有账号？去登录' : '没有账号？去注册'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
