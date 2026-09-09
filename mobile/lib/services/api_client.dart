import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> saveToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', token);
    }
  }

  String? get token => _token;
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
      final filename = image.name.isNotEmpty ? image.name : 'checkin.jpg';
      req.files.add(http.MultipartFile.fromBytes('image', bytes, filename: filename));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode >= 400 || map['success'] == false) {
      throw Exception(map['message']?.toString() ?? '请求失败');
    }
    return map;
  }
}
