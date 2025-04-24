import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class ChatHeader extends StatefulWidget {
  final String roomId;

  const ChatHeader({super.key, required this.roomId});

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  int participantCount = 0;
  late StompClient stompClient;

  @override
  void initState() {
    super.initState();

    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: 'http://192.168.219.41:8080/ws-chat',
        onConnect: (StompFrame frame) {
          stompClient.subscribe(
            destination: '/sub/chat/participants/${widget.roomId}',
            callback: (frame) {
              final count = int.tryParse(frame.body ?? '');
              if (count != null) {
                setState(() => participantCount = count);
              }
            },
          );

          // 처음 입장 시 참여 이벤트 전송
          stompClient.send(
            destination: '/pub/chat/join',
            body: jsonEncode({
              'roomId': widget.roomId,
              'username': 'FlutterUser',
            }),
          );
        },
        onWebSocketError: (e) => print('WebSocket error: $e'),
      ),
    );

    stompClient.activate();
  }

  @override
  void dispose() {
    stompClient.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text("👥 현재 참여자: $participantCount명",
          style: const TextStyle(fontSize: 16)),
    );
  }
}
