import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/api_client.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.instance.loadToken();
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
      home: ApiClient.instance.isLoggedIn ? const HomeShell() : const LoginScreen(),
    );
  }
}

Future<void> logoutAndGoLogin(BuildContext context) async {
  await ApiClient.instance.saveToken(null);
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}
