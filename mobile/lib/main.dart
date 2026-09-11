import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/chat_inbox.dart';
import 'theme.dart';

final rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.loadToken();
  await ChatInbox.instance.load();
  runApp(const LuckySignApp());
}

class LuckySignApp extends StatelessWidget {
  const LuckySignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '今日幸运签',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      home: ApiClient.instance.isLoggedIn ? const HomeShell() : const LoginScreen(),
    );
  }
}

Future<bool> confirmLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('退出登录'),
      content: const Text('确定要退出当前账号吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0392B)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('退出'),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> logoutAndGoLogin(BuildContext context, {bool askConfirm = true}) async {
  if (askConfirm) {
    final ok = await confirmLogout(context);
    if (!ok) return;
  }
  await ApiClient.instance.saveToken(null);
  await ChatInbox.instance.reset();
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
