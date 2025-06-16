import 'package:CHAT_SHIRE/service/unread_message_manager.dart';
import 'package:CHAT_SHIRE/widget/chat_header.dart';
import 'package:flutter/material.dart';

import '../widget/chat_input_widget.dart';
import '../widget/chat_receiver_widget.dart';

class ChatPage extends StatefulWidget {
  final String roomId;
  final String roomName;
  final bool isPrivate;

  const ChatPage({
    super.key,
    required this.roomId,
    required this.roomName,
    this.isPrivate = false,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  void initState() {
    super.initState();
    print(
        '🚪 ChatPage 진입 → roomId: ${widget.roomId} / isPrivate: ${widget.isPrivate}');

    // 🔥 채팅방 진입 시 즉시 읽음 처리 + 서버 동기화
    _markAsReadOnEnter();
  }

  // 🔥 채팅방 진입 시 읽음 처리 + 서버 동기화
  Future<void> _markAsReadOnEnter() async {
    try {
      // 서버 시간으로 읽음 처리 (이전 메시지들이 안읽음으로 표시되는 문제 해결)
      await UnreadMessageManager.syncReadTimeWithServer(widget.roomId);
      print('✅ 채팅방 진입 시 서버 동기화 완료: ${widget.roomId}');
    } catch (e) {
      print('❌ 채팅방 진입 시 서버 동기화 실패: $e');
      // 동기화 실패 시 일반 읽음 처리라도 실행
      try {
        await UnreadMessageManager.markAsRead(widget.roomId);
        print('✅ 채팅방 진입 시 일반 읽음 처리 완료: ${widget.roomId}');
      } catch (e2) {
        print('❌ 채팅방 진입 시 일반 읽음 처리도 실패: $e2');
      }
    }
  }

  // 🔥 뒤로가기 처리 공통 함수 (선택적 새로고침)
  Future<void> _handleBackNavigation(BuildContext context,
      {bool shouldRefresh = false}) async {
    try {
      // 🔥 서버와 읽음 시간 동기화
      await UnreadMessageManager.syncReadTimeWithServer(widget.roomId);
      print('✅ 채팅방 나가기 - 서버 동기화 완료: ${widget.roomId}');
    } catch (e) {
      print('❌ 채팅방 나가기 시 서버 동기화 실패: $e');
      // 동기화 실패 시 일반 읽음 처리라도 실행
      try {
        await UnreadMessageManager.markAsRead(widget.roomId);
        print('✅ 채팅방 나가기 - 일반 읽음 처리 완료: ${widget.roomId}');
      } catch (e2) {
        print('❌ 채팅방 나가기 시 일반 읽음 처리도 실패: $e2');
      }
    }

    Navigator.pop(context, {
      'shouldRefresh': shouldRefresh, // 🔥 선택적 새로고침
      'roomId': widget.roomId,
      'didRead': true   
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // 🔥 하드웨어 뒤로가기는 새로고침 안함 (불편함 해결)
          await _handleBackNavigation(context, shouldRefresh: false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.roomName),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              // 🔥 소프트웨어 뒤로가기는 새로고침 안함 (불편함 해결)
              await _handleBackNavigation(context, shouldRefresh: false);
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ChatHeader(roomId: widget.roomId, isPrivate: widget.isPrivate),
              Expanded(
                child: ChatReceiverWidget(
                  roomId: widget.roomId,
                  isPrivate: widget.isPrivate,
                ),
              ),
              const SizedBox(height: 16),
              ChatInputWidget(
                roomId: widget.roomId,
                isPrivate: widget.isPrivate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 🔥 dispose에서는 동기화만 실행 (과도한 처리 방지)
    UnreadMessageManager.syncReadTimeWithServer(widget.roomId).then((_) {
      print('✅ ChatPage dispose - 서버 동기화 완료: ${widget.roomId}');
    }).catchError((e) {
      print('❌ ChatPage dispose - 서버 동기화 실패: $e');
    });
    super.dispose();
  }
}
