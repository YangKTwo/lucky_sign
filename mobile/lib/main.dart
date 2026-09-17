import 'package:flutter/material.dart';

import 'app_keys.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'services/chat_inbox.dart';
import 'services/reminder_service.dart';
import 'services/session.dart';
import 'theme.dart';

export 'app_keys.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bindSessionHandlers();
  await ApiClient.instance.loadToken();
  await ChatInbox.instance.load();
  await ReminderService.instance.init();
  if (ApiClient.instance.isLoggedIn) {
    await ReminderService.instance.scheduleDaily();
  }
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
      navigatorKey: rootNavigatorKey,
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
  await logoutToLogin();
}
