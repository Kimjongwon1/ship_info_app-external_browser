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
  // 🔄 이전 연결이 있으면 종료
  if (stompClient.connected) {
    stompClient.deactivate();
  }

  stompClient = StompClient(
    config: StompConfig.SockJS(
      url: 'https://816e-118-131-64-204.ngrok-free.app/ws-chat',
      onConnect: (StompFrame frame) {
        isStompConnected = true;

        // 🔄 메시지 수신 구독
        stompClient.subscribe(
          destination: '/sub/chat/$roomId',
          callback: (StompFrame frame) {
            final data = jsonDecode(frame.body!);
            onMessage(data);
          },
        );

        onConnected?.call();
      },
      onWebSocketError: (dynamic error) => print('❌ WebSocket Error: $error'),
      onDisconnect: (frame) {
        isStompConnected = false;
        print("🔌 STOMP disconnected");
      },
    ),
  );

  stompClient.activate();
}

/// ✅ 참여자 수 구독
void subscribeParticipantCount(String roomId, Function(int) onUpdate) {
  if (!stompClient.connected) {
    print("⚠️ STOMP 연결되지 않음 → 참여자 구독 실패");
    return;
  }

  stompClient.subscribe(
    destination: '/sub/chat/participants/$roomId',
    callback: (frame) {
      final count = int.tryParse(frame.body ?? '');
      if (count != null) {
        onUpdate(count);

        // 💡 0명일 경우 재참여 보정용 로그
        if (count == 0) {
          print("⚠️ 참여자 수 0 → STOMP 재참여 필요할 수 있음");
        }
      }
    },
  );
}

/// ✅ 메시지 전송
void sendMessage(String sender, String message, String roomId) {
  final msg = {
    'sender': sender,
    'message': message,
    'roomId': roomId,
  };
  stompClient.send(destination: '/pub/chat/message', body: jsonEncode(msg));
}

/// ✅ 참여 이벤트 전송 (초기 진입 시 또는 보정용)
void sendJoinEvent(String roomId, String username) {
  if (stompClient.connected) {
    print('📤 JOIN: $username → $roomId');
    stompClient.send(
      destination: '/pub/chat/join',
      body: jsonEncode({
        'roomId': roomId,
        'username': username,
      }),
    );
  } else {
    print("❌ STOMP 연결 안됨 → JOIN 이벤트 전송 불가");
  }
}

/// ✅ 퇴장 이벤트 전송
void sendLeaveEvent(String roomId, String username) {
  if (stompClient.connected) {
    print('📤 LEAVE: $username → $roomId');
    stompClient.send(
      destination: '/pub/chat/leave',
      body: jsonEncode({
        'roomId': roomId,
        'username': username,
      }),
    );
  }
}
