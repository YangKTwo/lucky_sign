import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config.dart';
import 'api_client.dart';

class ChatSocket {
  StompClient? _client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  int? _circleId;

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  int? get circleId => _circleId;

  void connect({int? circleId}) {
    disconnect();
    final token = ApiClient.instance.token;
    if (token == null || token.isEmpty) {
      debugPrint('ChatSocket: skip connect, no token');
      return;
    }
    _circleId = circleId ?? ApiClient.instance.circleId;
    if (_circleId == null) {
      debugPrint('ChatSocket: skip connect, no circleId');
      return;
    }
    final cid = _circleId;
    _client = StompClient(
      config: StompConfig(
        url: wsBaseUrl,
        onConnect: (frame) {
          _client?.subscribe(
            destination: '/topic/chat/$cid',
            callback: (frame) {
              if (frame.body == null) return;
              final data = jsonDecode(frame.body!) as Map<String, dynamic>;
              _controller.add(data);
            },
          );
        },
        stompConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $token',
        },
        onWebSocketError: (e) => debugPrint('ChatSocket ws error: $e'),
        onStompError: (frame) => debugPrint('ChatSocket stomp error: ${frame.body}'),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  void sendText(String content) {
    final cid = _circleId;
    if (cid != null) {
      _client?.send(
        destination: '/app/chat.send/$cid',
        body: jsonEncode({'content': content}),
      );
    } else {
      _client?.send(
        destination: '/app/chat.send',
        body: jsonEncode({'content': content}),
      );
    }
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
    _circleId = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
