/// 默认连云端；可用 --dart-define=API_BASE=... 覆盖
const String _defaultApi = 'http://119.23.45.226:8080';
const String _defaultWs = 'ws://119.23.45.226:8080/ws';

String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  return _defaultApi;
}

String get wsBaseUrl {
  const fromEnv = String.fromEnvironment('WS_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  return _defaultWs;
}
