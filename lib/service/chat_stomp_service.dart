import 'dart:convert';

import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

late StompClient stompClient;

void connectStomp(Function(Map<String, dynamic>) onMessage) {
  stompClient = StompClient(
    config: StompConfig.SockJS(
      url: 'http://192.168.219.41:8080/ws-chat', // 👉 실제 서버 IP로 바꿔야 함
      onConnect: (StompFrame frame) {
        stompClient.subscribe(
          destination: '/sub/chat/message',
          callback: (StompFrame frame) {
            final data = jsonDecode(frame.body!);
            onMessage(data);
          },
        );
      },
      onWebSocketError: (dynamic error) => print('WebSocket Error: $error'),
    ),
  );

  stompClient.activate();
}

void sendMessage(String sender, String message) {
  final msg = {
    'sender': sender,
    'message': message,
  };
  stompClient.send(destination: '/pub/chat/message', body: jsonEncode(msg));
}
