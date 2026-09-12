import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  String? _refreshToken;
  int? _userId;
  int? _circleId;
  bool _isRefreshing = false;

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
    if (_isRefreshing || _refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }
    _isRefreshing = true;
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
            return true;
          }
        }
      }
      await saveToken(null);
      return false;
    } catch (e) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body, {bool retry = true}) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 401 && retry && !path.contains('/auth/')) {
      if (await _tryRefreshToken()) {
        return postJson(path, body, retry: false);
      }
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> getJson(String path, {bool retry = true}) async {
    final res = await http.get(Uri.parse('$apiBaseUrl$path'), headers: _headers());
    if (res.statusCode == 401 && retry && !path.contains('/auth/')) {
      if (await _tryRefreshToken()) {
        return getJson(path, retry: false);
      }
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body, {bool retry = true}) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (res.statusCode == 401 && retry && !path.contains('/auth/')) {
      if (await _tryRefreshToken()) {
        return putJson(path, body, retry: false);
      }
    }
    return _decode(res);
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
    if (res.statusCode == 401 && retry) {
      if (await _tryRefreshToken()) {
        return completeCheckin(text: text, image: image, retry: false);
      }
    }
    return _decode(res);
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
    if (res.statusCode == 401 && retry) {
      if (await _tryRefreshToken()) {
        return uploadAvatar(image, retry: false);
      }
    }
    return _decode(res);
  }

  Future<Map<String, dynamic>> rateCheckin(int checkinId, int score) async {
    return postJson('/api/checkin/$checkinId/rate', {'score': score});
  }

  Future<Map<String, dynamic>> checkinDetail(int checkinId) async {
    return getJson('/api/checkin/$checkinId');
  }

  Map<String, dynamic> _decode(http.Response res) {
    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
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
