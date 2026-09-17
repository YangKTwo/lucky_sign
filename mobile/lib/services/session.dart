import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_keys.dart';
import '../screens/login_screen.dart';
import 'api_client.dart';
import 'chat_inbox.dart';

export 'api_client.dart' show SessionExpiredException;

bool _handlingSessionExpired = false;

/// 登录成功后重置，允许下次再触发过期处理。
void resetSessionExpiredGuard() {
  _handlingSessionExpired = false;
}

/// 在应用启动时调用，把过期处理挂到 ApiClient。
void bindSessionHandlers() {
  ApiClient.instance.onSessionExpired = forceLogoutToLogin;
  ApiClient.instance.onSessionRestored = resetSessionExpiredGuard;
}

Future<void> _clearLocalSession() async {
  await ApiClient.instance.saveToken(null);
  await ChatInbox.instance.reset();
  final prefs = await SharedPreferences.getInstance();
  final lastEmail = prefs.getString('lastEmail');
  await prefs.clear();
  if (lastEmail != null && lastEmail.isNotEmpty) {
    await prefs.setString('lastEmail', lastEmail);
  }
}

void _goLogin() {
  void navigate() {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  final nav = rootNavigatorKey.currentState;
  if (nav != null) {
    navigate();
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) => navigate());
}

/// 主动退出：清会话并回登录页。
Future<void> logoutToLogin() async {
  resetSessionExpiredGuard();
  await _clearLocalSession();
  _goLogin();
}

/// Token 过期：清会话、跳转登录，并提示一次。可安全并发调用。
Future<void> forceLogoutToLogin({
  String message = '登录已过期，请重新登录',
}) async {
  if (_handlingSessionExpired) return;
  _handlingSessionExpired = true;

  try {
    await _clearLocalSession();
    _goLogin();

    // 稍等，清掉各页面 catch 里可能弹出的重复 SnackBar
    await Future<void>.delayed(const Duration(milliseconds: 80));
    rootScaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  } catch (_) {
    _handlingSessionExpired = false;
    rethrow;
  }
}
