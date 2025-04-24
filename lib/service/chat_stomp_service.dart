import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

late StompClient stompClient;
bool isStompConnected = false;

/// ✅ 방 구독
void connectStomp(String roomId, Function(Map<String, dynamic>) onMessage,
    {VoidCallback? onConnected}) {
  stompClient = StompClient(
    config: StompConfig.SockJS(
      url: 'http://192.168.219.41:8080/ws-chat',
      onConnect: (StompFrame frame) {
        isStompConnected = true;
        stompClient.subscribe(
          destination: '/sub/chat/$roomId', // ✅ 방 구독
          callback: (StompFrame frame) {
            final data = jsonDecode(frame.body!);
            onMessage(data);
          },
        );
        onConnected?.call();
      },
      onWebSocketError: (dynamic error) => print('WebSocket Error: $error'),
    ),
  );

  stompClient.activate();
}

void subscribeParticipantCount(String roomId, Function(int) onUpdate) {
  stompClient.subscribe(
    destination: '/sub/chat/participants/$roomId',
    callback: (frame) {
      final count = int.tryParse(frame.body ?? '');
      if (count != null) {
        onUpdate(count);
      }
    },
  );
}

/// ✅ roomId도 같이 전송
void sendMessage(String sender, String message, String roomId) {
  final msg = {
    'sender': sender,
    'message': message,
    'roomId': roomId,
  };
  stompClient.send(destination: '/pub/chat/message', body: jsonEncode(msg));
}
