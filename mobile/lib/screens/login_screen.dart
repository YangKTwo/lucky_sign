import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/reminder_service.dart';
import '../theme.dart';
import '../utils/errors.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _inviteCode = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _error;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    _restoreLastEmail();
  }

  Future<void> _restoreLastEmail() async {
    final last = await ApiClient.instance.lastEmail();
    if (!mounted || last == null || last.isEmpty) return;
    _email.text = last;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nickname.dispose();
    _confirmPassword.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

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
        if (_registerMode) 'inviteCode': _inviteCode.text.trim(),
      };
      final res = await ApiClient.instance.postJson(path, body);
      final data = res['data'] as Map<String, dynamic>?;
      if (data == null) {
        throw Exception('登录响应异常，请稍后重试');
      }
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) {
        throw Exception('未拿到登录凭证，请重试');
      }
      final refreshToken = data['refreshToken'] as String?;
      final profile = data['profile'] as Map<String, dynamic>?;
      await ApiClient.instance.saveToken(token, refreshToken: refreshToken);
      await ApiClient.instance.saveLastEmail(_email.text.trim());
      await ReminderService.instance.scheduleDaily();
      final id = profile?['id'];
      if (id is int) {
        await ApiClient.instance.saveUserId(id);
      } else if (id is num) {
        await ApiClient.instance.saveUserId(id.toInt());
      }
      final circleId = data['circleId'];
      if (circleId is int) {
        await ApiClient.instance.saveCircleId(circleId);
      } else if (circleId is num) {
        await ApiClient.instance.saveCircleId(circleId.toInt());
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _registerMode = !_registerMode;
      _error = null;
      _confirmPassword.clear();
    });
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
          child: Form(
            key: _formKey,
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
                  _registerMode ? '填写邀请码加入小圈子' : '每天一签，完成任务攒积分',
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
                        TextFormField(
                          controller: _nickname,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                            labelText: '昵称',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return '请填写昵称';
                            if (t.length > 32) return '昵称最多 32 字';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _inviteCode,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: const InputDecoration(
                            labelText: '邀请码',
                            hintText: '向圈子成员索取',
                            prefixIcon: Icon(Icons.vpn_key_outlined),
                          ),
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return '请填写邀请码';
                            if (t.length < 4) return '邀请码不正确';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        decoration: const InputDecoration(
                          labelText: '邮箱',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return '请填写邮箱';
                          if (!_emailRegex.hasMatch(t)) return '邮箱格式不正确';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        textInputAction: _registerMode ? TextInputAction.next : TextInputAction.done,
                        autofillHints: [
                          _registerMode ? AutofillHints.newPassword : AutofillHints.password,
                        ],
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        onFieldSubmitted: (_) {
                          if (!_registerMode) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: '密码',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                        ),
                        validator: (v) {
                          final t = v ?? '';
                          if (t.isEmpty) return '请填写密码';
                          if (_registerMode && t.length < 8) return '密码至少 8 位';
                          return null;
                        },
                      ),
                      if (_registerMode) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPassword,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: '确认密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              icon: Icon(
                                _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if ((v ?? '') != _password.text) return '两次密码不一致';
                            return null;
                          },
                        ),
                      ],
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
                        onPressed: _loading ? null : _toggleMode,
                        child: Text(_registerMode ? '已有账号？去登录' : '没有账号？去注册'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
