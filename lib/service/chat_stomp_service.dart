import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

late StompClient stompClient;
bool isStompConnected = false;

/// ✅ 방 구독
void connectStomp(
  String roomId,
  Function(Map<String, dynamic>) onMessage, {
  VoidCallback? onConnected,
  bool isPrivate = false,
}) async {
  final destination =
      isPrivate ? '/sub/chat/private/$roomId' : '/sub/chat/$roomId';

  if (stompClient.connected) {
    stompClient.deactivate(); // ✅ 반드시 기다려야 함
  }

  stompClient = StompClient(
    config: StompConfig.SockJS(
      url: 'https://f4ab-118-131-64-204.ngrok-free.app/ws-chat',
      onConnect: (StompFrame frame) {
        isStompConnected = true;
        print("📡 STOMP 연결됨 → 구독 주소: $destination");

        // ✅ 안전하게 마이크로태스크로 subscribe 지연
        Future.microtask(() {
          try {
            stompClient.subscribe(
              destination: destination,
              callback: (StompFrame frame) {
                final data = jsonDecode(frame.body!);
                onMessage(data);
              },
            );
            onConnected?.call();
          } catch (e) {
            print("❌ subscribe 실패: $e");
          }
        });
      },
      onDisconnect: (frame) {
        isStompConnected = false;
        print("🔌 STOMP 연결 종료됨");
      },
    ),
  );

  stompClient.activate();
}

/// ✅ 참여자 수 구독
void subscribeParticipantCount(String roomId, Function(int) onUpdate,
    {bool isPrivate = false}) {
  if (!stompClient.connected) {
    print("⚠️ STOMP 연결되지 않음 → 참여자 구독 실패");
    return;
  }

  if (isPrivate) {
    print("🛑 개인 채팅방 → 참여자 수 구독 생략");
    return;
  }

  print("📡 STOMP 연결됨 → 참여자 수 구독 시작");
  stompClient.subscribe(
    destination: '/sub/chat/participants/$roomId',
    callback: (frame) {
      final count = int.tryParse(frame.body ?? '');
      if (count != null) {
        onUpdate(count);

        if (count == 0) {
          print("⚠️ 참여자 수 0 → STOMP 재참여 필요할 수 있음");
        }
      }
    },
  );
}

/// ✅ 메시지 전송
void sendMessage(String sender, String message, String roomId,
    {bool isPrivate = false}) {
  final dest = isPrivate ? '/pub/chat/private/message' : '/pub/chat/message';

  final body = jsonEncode({
    'sender': sender,
    'message': message,
    'roomId': roomId,
  });

  stompClient.send(
    destination: dest,
    body: body,
  );

  debugPrint('📤 메시지 전송 → $dest : $body');
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
    // print('📤 LEAVE: $username → $roomId');
    stompClient.send(
      destination: '/pub/chat/leave',
      body: jsonEncode({
        'roomId': roomId,
        'username': username,
      }),
    );
  }
}
