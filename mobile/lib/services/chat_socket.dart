import 'dart:async';
import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config.dart';
import 'api_client.dart';

class ChatSocket {
  StompClient? _client;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void connect() {
    disconnect();
    final token = ApiClient.instance.token;
    _client = StompClient(
      config: StompConfig(
        url: wsBaseUrl,
        onConnect: (frame) {
          _client?.subscribe(
            destination: '/topic/chat',
            callback: (frame) {
              if (frame.body == null) return;
              final data = jsonDecode(frame.body!) as Map<String, dynamic>;
              _controller.add(data);
            },
          );
        },
        stompConnectHeaders: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
        webSocketConnectHeaders: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
        onWebSocketError: (e) {},
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  void sendText(String content) {
    _client?.send(
      destination: '/app/chat.send',
      body: jsonEncode({'content': content}),
    );
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }

  void dispose() {
    disconnect();
    _controller.close();
  }
}
