import 'package:flutter/foundation.dart';

String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  // Android 模拟器访问本机用 10.0.2.2；Chrome/桌面用 localhost
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8080';
  }
  return 'http://localhost:8080';
}

String get wsBaseUrl {
  const fromEnv = String.fromEnvironment('WS_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'ws://10.0.2.2:8080/ws';
  }
  return 'ws://localhost:8080/ws';
}
