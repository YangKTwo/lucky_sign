import 'package:flutter/foundation.dart';

/// 默认连云端（原生 App）；可用 --dart-define=API_BASE=... / WS_BASE=... 覆盖。
/// Web 未指定时走当前页面同源（方便挂在同一后端 /app/ 下）。
const String _defaultApi = 'http://119.23.45.226:8080';
const String _defaultWs = 'ws://119.23.45.226:8080/ws';
const String _unset = '__unset__';

String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE', defaultValue: _unset);
  if (fromEnv != _unset) return fromEnv;
  if (kIsWeb) return '';
  return _defaultApi;
}

String get wsBaseUrl {
  const fromEnv = String.fromEnvironment('WS_BASE', defaultValue: _unset);
  if (fromEnv != _unset) return fromEnv;
  if (kIsWeb) return _wsFromPageOrigin();
  return _defaultWs;
}

String _wsFromPageOrigin() {
  final u = Uri.base;
  final scheme = u.scheme == 'https' ? 'wss' : 'ws';
  final port = u.hasPort ? ':${u.port}' : '';
  return '$scheme://${u.host}$port/ws';
}
