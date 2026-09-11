import 'package:flutter/foundation.dart';

/// API/WebSocket configuration.
///
/// Production builds: inject via --dart-define:
///   flutter build apk --dart-define=API_BASE=https://api.example.com \
///                     --dart-define=WS_BASE=wss://api.example.com/ws
///
/// Debug builds: use http://localhost:8080 or set environment variables.
/// Web builds: default to same-origin (relative URLs).
///
/// IMPORTANT: Never hardcode production URLs with public IPs in source code.
const String _unset = '__unset__';

String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE', defaultValue: _unset);
  if (fromEnv != _unset) return fromEnv;
  if (kIsWeb) return '';
  if (kDebugMode) return 'http://localhost:8080';
  throw StateError('API_BASE must be set for release builds via --dart-define=API_BASE=https://...');
}

String get wsBaseUrl {
  const fromEnv = String.fromEnvironment('WS_BASE', defaultValue: _unset);
  if (fromEnv != _unset) return fromEnv;
  if (kIsWeb) return _wsFromPageOrigin();
  if (kDebugMode) return 'ws://localhost:8080/ws';
  throw StateError('WS_BASE must be set for release builds via --dart-define=WS_BASE=wss://...');
}

String _wsFromPageOrigin() {
  final u = Uri.base;
  final scheme = u.scheme == 'https' ? 'wss' : 'ws';
  final port = u.hasPort ? ':${u.port}' : '';
  return '$scheme://${u.host}$port/ws';
}
