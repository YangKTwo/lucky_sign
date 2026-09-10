import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  int? _userId;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _userId = prefs.getInt('userId');
  }

  Future<void> saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('token');
      await prefs.remove('userId');
      _userId = null;
    } else {
      await prefs.setString('token', token);
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

  String? get token => _token;
  int? get userId => _userId;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final res = await http.get(Uri.parse('$apiBaseUrl$path'), headers: _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> putJson(String path, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$apiBaseUrl$path'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> completeCheckin({String? text, XFile? image}) async {
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
    return _decode(res);
  }

  Future<Map<String, dynamic>> uploadAvatar(XFile image) async {
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
    return _decode(res);
  }

  Future<Map<String, dynamic>> rateCheckin(int checkinId, int score) async {
    return postJson('/api/checkin/$checkinId/rate', {'score': score});
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
