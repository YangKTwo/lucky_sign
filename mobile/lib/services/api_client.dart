import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// 由 main 注册：刷新失败后清会话并跳转登录。
typedef SessionExpiredCallback = Future<void> Function();

class SessionExpiredException implements Exception {
  @override
  String toString() => '登录已过期，请重新登录';
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  String? _refreshToken;
  int? _userId;
  int? _circleId;
  Completer<bool>? _refreshCompleter;
  SessionExpiredCallback? onSessionExpired;
  void Function()? onSessionRestored;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> loadToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      _refreshToken = prefs.getString('refreshToken');
    } else {
      _token = await _secureStorage.read(key: 'token');
      _refreshToken = await _secureStorage.read(key: 'refreshToken');
    }
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId');
    _circleId = prefs.getInt('circleId');
  }

  Future<void> saveToken(String? token, {String? refreshToken}) async {
    _token = token;
    if (refreshToken != null) {
      _refreshToken = refreshToken;
    }

    if (token != null && token.isNotEmpty) {
      onSessionRestored?.call();
    }

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove('token');
        await prefs.remove('refreshToken');
        await prefs.remove('userId');
        await prefs.remove('circleId');
        _userId = null;
        _circleId = null;
        _refreshToken = null;
      } else {
        await prefs.setString('token', token);
        if (refreshToken != null) {
          await prefs.setString('refreshToken', refreshToken);
        }
      }
    } else {
      if (token == null) {
        await _secureStorage.delete(key: 'token');
        await _secureStorage.delete(key: 'refreshToken');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('userId');
        await prefs.remove('circleId');
        _userId = null;
        _circleId = null;
        _refreshToken = null;
      } else {
        await _secureStorage.write(key: 'token', value: token);
        if (refreshToken != null) {
          await _secureStorage.write(key: 'refreshToken', value: refreshToken);
        }
      }
    }
  }

  Future<void> saveUserId(int? userId) async {
    _userId = userId;
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove('userId');
    } else {
      await prefs.setInt('userId', userId);
    }
  }

  Future<void> saveCircleId(int? circleId) async {
    _circleId = circleId;
    final prefs = await SharedPreferences.getInstance();
    if (circleId == null) {
      await prefs.remove('circleId');
    } else {
      await prefs.setInt('circleId', circleId);
    }
  }

  String? get token => _token;
  String? get refreshToken => _refreshToken;
  int? get userId => _userId;
  int? get circleId => _circleId;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Future<void> saveLastEmail(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    final v = email?.trim() ?? '';
    if (v.isEmpty) {
      await prefs.remove('lastEmail');
    } else {
      await prefs.setString('lastEmail', v);
    }
  }

  Future<String?> lastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('lastEmail');
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final res = await http.post(
        Uri.parse('$apiBaseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
      if (res.statusCode == 200) {
        final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        if (map['success'] == true) {
          final data = map['data'] as Map<String, dynamic>?;
          final newToken = data?['token'] as String?;
          final newRefresh = data?['refreshToken'] as String?;
          if (newToken != null && newToken.isNotEmpty) {
            await saveToken(newToken, refreshToken: newRefresh);
            completer.complete(true);
            return true;
          }
        }
      }
      await saveToken(null);
      completer.complete(false);
      return false;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }

  Future<Never> _onUnauthorized() async {
    // 不 await 跳转，尽快让调用方收到异常；跳转与提示在后台完成
    final handler = onSessionExpired;
    if (handler != null) {
      unawaited(handler());
    }
    throw SessionExpiredException();
  }

  Future<Map<String, dynamic>> _afterUnauthorized(
    http.Response res, {
    required bool retry,
    required bool isAuthPath,
    required Future<Map<String, dynamic>> Function() retryCall,
  }) async {
    if (res.statusCode != 401) {
      return _decode(res);
    }
    if (isAuthPath) {
      return _decode(res);
    }
    if (retry && await _tryRefreshToken()) {
      return retryCall();
    }
    return _onUnauthorized();
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body, {bool retry = true}) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _afterUnauthorized(
      res,
      retry: retry,
      isAuthPath: path.contains('/auth/'),
      retryCall: () => postJson(path, body, retry: false),
    );
  }

  Future<Map<String, dynamic>> getJson(String path, {bool retry = true}) async {
    final res = await http.get(Uri.parse('$apiBaseUrl$path'), headers: _headers());
    return _afterUnauthorized(
      res,
      retry: retry,
      isAuthPath: path.contains('/auth/'),
      retryCall: () => getJson(path, retry: false),
    );
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body, {bool retry = true}) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _afterUnauthorized(
      res,
      retry: retry,
      isAuthPath: path.contains('/auth/'),
      retryCall: () => putJson(path, body, retry: false),
    );
  }

  Future<Map<String, dynamic>> completeCheckin({String? text, XFile? image, bool retry = true}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/checkin/complete'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    if (text != null && text.isNotEmpty) {
      req.fields['text'] = text;
    }
    if (image != null) {
      final bytes = await image.readAsBytes();
      final filename = _imageFilename(image);
      req.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: filename,
        contentType: _imageMediaType(image, filename),
      ));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _afterUnauthorized(
      res,
      retry: retry,
      isAuthPath: false,
      retryCall: () => completeCheckin(text: text, image: image, retry: false),
    );
  }

  Future<Map<String, dynamic>> uploadAvatar(XFile image, {bool retry = true}) async {
    final req = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/api/user/avatar'));
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    final bytes = await image.readAsBytes();
    final filename = _imageFilename(image);
    req.files.add(http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
      contentType: _imageMediaType(image, filename),
    ));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _afterUnauthorized(
      res,
      retry: retry,
      isAuthPath: false,
      retryCall: () => uploadAvatar(image, retry: false),
    );
  }

  Future<Map<String, dynamic>> rateCheckin(int checkinId, int score) async {
    return postJson('/api/checkin/$checkinId/rate', {'score': score});
  }

  Future<Map<String, dynamic>> checkinDetail(int checkinId) async {
    return getJson('/api/checkin/$checkinId');
  }

  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> map;
    try {
      map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      if (res.statusCode == 401) {
        throw SessionExpiredException();
      }
      throw Exception(res.statusCode >= 400 ? '请求失败（${res.statusCode}）' : '响应解析失败');
    }
    if (res.statusCode >= 400 || map['success'] == false) {
      throw Exception(map['message']?.toString() ?? '请求失败');
    }
    return map;
  }

  String _imageFilename(XFile image) {
    final name = image.name.trim();
    if (name.isNotEmpty && name.contains('.')) return name;
    final mime = image.mimeType?.toLowerCase() ?? '';
    if (mime.contains('png')) return 'checkin.png';
    if (mime.contains('webp')) return 'checkin.webp';
    return 'checkin.jpg';
  }

  MediaType _imageMediaType(XFile image, String filename) {
    final mime = image.mimeType?.toLowerCase().split(';').first.trim();
    if (mime != null && mime.startsWith('image/')) {
      final parts = mime.split('/');
      if (parts.length == 2 && parts[1].isNotEmpty) {
        final subtype = parts[1] == 'jpg' ? 'jpeg' : parts[1];
        return MediaType('image', subtype);
      }
    }
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'jpeg');
  }
}
