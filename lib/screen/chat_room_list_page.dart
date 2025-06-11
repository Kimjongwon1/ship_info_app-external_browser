import 'dart:convert';

import 'package:CHAT_SHIRE/model/chat_room.dart';
import 'package:CHAT_SHIRE/service/unread_message_manager.dart';
import 'package:CHAT_SHIRE/util/route_path.dart';
import 'package:chat_config/chat_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../service/chat_api_service.dart';
import 'chat_page.dart';

class ChatRoomListPage extends StatefulWidget {
  const ChatRoomListPage({super.key});

  @override
  State<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  List<ChatRoom> allRooms = [];
  List<ChatRoom> filteredRooms = [];
  Map<String, int> unreadCounts = {}; // 🔥 안읽은 메시지 개수 저장
  Map<String, String> lastMessages = {}; // 🔥 마지막 메시지 저장
  Map<String, String> lastMessageTimes = {}; // 🔥 마지막 메시지 시간 저장

  bool isLoading = true;
  String searchKeyword = "";
  String role = '';
  String userId = '';
  String username = ''; // 🔥 실시간 메시지 구분용

  late StompClient messageClient; // 🔥 실시간 메시지용 클라이언트
  bool _isMessageClientConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchRooms();
    _subscribeToRealTimeMessages(); // 🔥 실시간 메시지 구독
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? '';
      userId = prefs.getString('userId') ?? '';
      username = prefs.getString('username') ?? ''; // 🔥 username 로드
    });
  }

  // 🔥 안읽은 메시지 개수 및 마지막 메시지 로드 (UnreadMessageManager 사용)
  Future<void> _loadUnreadCounts() async {
    if (allRooms.isEmpty) return;

    for (var room in allRooms) {
      final roomId = room.id.toString();

      try {
        // 🔥 UnreadMessageManager 사용해서 안읽은 메시지 개수 조회
        final unreadCount = await UnreadMessageManager.getUnreadCount(roomId);

        // 🔥 UnreadMessageManager 사용해서 마지막 메시지 정보 조회
        final lastMessageData =
            await UnreadMessageManager.getLastMessage(roomId);

        setState(() {
          unreadCounts[roomId] = unreadCount;
          if (lastMessageData != null) {
            lastMessages[roomId] = UnreadMessageManager.cleanMessageText(
                lastMessageData['message'] ?? '');
            lastMessageTimes[roomId] =
                UnreadMessageManager.formatTime(lastMessageData['timestamp']);
          }
        });
      } catch (e) {
        print('❌ 방 $roomId 안읽은 메시지 로드 실패: $e');
      }
    }
  }

  // 🔥 메시지가 내가 보낸 것인지 체크하는 함수
  bool _isMyMessage(Map<String, dynamic> messageData) {
    final sender = messageData['sender'] ?? messageData['senderId'] ?? '';
    final senderName = messageData['senderName'] ?? '';

    // userId로 체크
    if (sender.isNotEmpty && sender == userId) {
      return true;
    }

    // username으로도 체크
    if (senderName.isNotEmpty && senderName == username) {
      return true;
    }

    return false;
  }

  // 🔥 실시간 메시지 구독
  void _subscribeToRealTimeMessages() async {
    if (_isMessageClientConnected) {
      print('⚠️ 이미 실시간 메시지 클라이언트가 연결되어 있습니다');
      return;
    }

    messageClient = StompClient(
      config: StompConfig.SockJS(
        url: ApiConfig.wsUrl,
        onConnect: (StompFrame frame) {
          print('✅ 실시간 메시지 WebSocket 연결됨');
          _isMessageClientConnected = true;

          // 모든 방의 실시간 메시지 구독
          _subscribeToAllRoomMessages();
        },
        onDisconnect: (frame) {
          print('❌ 실시간 메시지 WebSocket 연결 해제됨');
          _isMessageClientConnected = false;
        },
        onWebSocketError: (error) {
          print('❌ 실시간 메시지 WebSocket 오류: $error');
          _isMessageClientConnected = false;
        },
      ),
    );
    messageClient.activate();
  }

  // 🔥 모든 방의 실시간 메시지 구독
  void _subscribeToAllRoomMessages() {
    print('🔔 일반 채팅방 실시간 메시지 구독 시작 - 방 개수: ${allRooms.length}');

    for (var room in allRooms) {
      final roomId = room.id.toString();
      print('📡 방 $roomId 실시간 메시지 구독');

      messageClient.subscribe(
        destination: '/sub/chat/$roomId', // 일반 채팅방 경로
        callback: (frame) {
          if (!mounted) return;

          try {
            final messageData = jsonDecode(frame.body ?? '{}');

            print('🔍 실시간 메시지 수신 - 방: $roomId');
            print('📋 메시지 데이터: $messageData');

            // 내가 보낸 메시지인지 체크
            final isMyMessage = _isMyMessage(messageData);
            print('🔍 내 메시지 여부: $isMyMessage');

            // 내가 보낸 메시지가 아닌 경우에만 안읽은 개수 증가
            if (!isMyMessage) {
              setState(() {
                unreadCounts[roomId] = (unreadCounts[roomId] ?? 0) + 1;
                lastMessages[roomId] = UnreadMessageManager.cleanMessageText(
                    messageData['message'] ?? '');
                lastMessageTimes[roomId] =
                    UnreadMessageManager.formatTime(messageData['timestamp']);
              });
              print('📈 안읽은 메시지 증가: ${unreadCounts[roomId]}');
            } else {
              print('🚫 내가 보낸 메시지이므로 안읽은 개수 증가하지 않음');
            }
          } catch (e) {
            print('❌ 실시간 메시지 처리 오류: $e');
          }
        },
      );
    }
  }

  Future<void> _fetchRooms() async {
    setState(() => isLoading = true);
    try {
      final rooms = await ChatApiService.fetchRoomList();
      setState(() {
        allRooms = rooms;
        _applyFilter();
      });

      // 🔥 안읽은 메시지 개수 로드
      await _loadUnreadCounts();

      // 🔥 방 목록 로드 후 실시간 메시지 구독 설정
      if (_isMessageClientConnected) {
        _subscribeToAllRoomMessages();
      }

      // 🔥 인원수 관련 코드 제거 (connectStompForRoomList 제거)
    } catch (e) {
      print("❌ 채팅방 목록 오류: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  // 🔥 참여자 수 관련 메서드 제거
  // Future<void> _fetchParticipantsForRooms(List<ChatRoom> rooms) async {

  void _applyFilter() {
    setState(() {
      filteredRooms =
          allRooms.where((room) => room.name.contains(searchKeyword)).toList();
    });
  }

  void _showCreateRoomDialog() {
    final TextEditingController nameController = TextEditingController();
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("새 채팅방 만들기"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "방 이름"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "비밀번호 (선택)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final password = passwordController.text.trim();
              if (name.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                final createId = prefs.getString('userId') ?? '';
                await ChatApiService.createRoom(
                  name,
                  password,
                  createId,
                );
                Navigator.pop(context);
                _fetchRooms(); // 방 생성 후 목록 새로고침
              }
            },
            child: const Text("생성"),
          ),
        ],
      ),
    );
  }

  // 🔥 참여자 수 관련 connectStompForRoomList 메서드 제거

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("💬실시간 채팅방 목록"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                icon: const Icon(Icons.home),
                onPressed: () {
                  Navigator.pushNamed(context, RoutePath.shipList);
                }),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchRooms,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateRoomDialog,
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: "방 이름 검색",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        searchKeyword = value;
                        _applyFilter();
                      },
                    ),
                  ),
                  Expanded(
                    child: filteredRooms.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "채팅방이 없습니다",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "우상단 + 버튼으로 새 채팅방을 만들어보세요",
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredRooms.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 18),
                            itemBuilder: (context, index) {
                              final room = filteredRooms[index];
                              final roomId =
                                  room.id.toString(); // int -> String 변환
                              final roomName = room.name;

                              // 🔥 안읽은 메시지 관련 데이터
                              final unreadCount = unreadCounts[roomId] ?? 0;
                              final lastMessage = lastMessages[roomId] ?? '';
                              final lastTime = lastMessageTimes[roomId] ?? '';

                              return Card(
                                elevation: 2,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Stack(
                                    children: [
                                      Icon(
                                        room.password != null &&
                                                room.password!.isNotEmpty
                                            ? Icons.lock_outline
                                            : Icons.chat_bubble_outline,
                                        color: room.password != null &&
                                                room.password!.isNotEmpty
                                            ? Colors.red
                                            : Colors.blue,
                                        size: 32,
                                      ),
                                      // 🔥 안읽은 메시지 뱃지
                                      if (unreadCount > 0)
                                        Positioned(
                                          right: -2,
                                          top: -2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 16,
                                              minHeight: 16,
                                            ),
                                            child: Text(
                                              unreadCount > 99
                                                  ? '99+'
                                                  : '$unreadCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          room.name,
                                          style: TextStyle(
                                            fontWeight: unreadCount > 0
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      if (lastTime.isNotEmpty)
                                        Text(
                                          lastTime,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: lastMessage.isNotEmpty
                                      ? Text(
                                          lastMessage,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: unreadCount > 0
                                                ? Colors.grey.shade700
                                                : Colors.grey.shade500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : null, // 🔥 인원수 표시 제거
                                  onTap: () async {
                                    // 🔥 채팅방 입장 시 읽음 처리
                                    await UnreadMessageManager.markAsRead(
                                        roomId);
                                    setState(() {
                                      unreadCounts[roomId] = 0;
                                    });

                                    if (role == "ROLE_MASTER" ||
                                        room.createId == userId) {
                                      // 마스터는 비밀번호 없이 입장
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ChatPage(
                                                  roomId: room.id.toString(),
                                                  roomName: room.name,
                                                )),
                                      );

                                      // 🔥 ChatPage에서 돌아왔을 때 처리
                                      if (result != null &&
                                          result['shouldRefresh'] == true) {
                                        final returnedRoomId = result['roomId'];
                                        setState(() {
                                          unreadCounts[returnedRoomId] = 0;
                                        });
                                        await Future.delayed(
                                            const Duration(milliseconds: 200));
                                        await _loadUnreadCounts();
                                      }
                                      return;
                                    }

                                    if (room.password != null &&
                                        room.password!.isNotEmpty) {
                                      final controller =
                                          TextEditingController();
                                      final input = await showDialog<String>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text("비밀번호 입력"),
                                          content: TextField(
                                            controller: controller,
                                            obscureText: true,
                                            decoration: const InputDecoration(
                                                hintText: "비밀번호"),
                                          ),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, null),
                                                child: const Text("취소")),
                                            ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                    context, controller.text),
                                                child: const Text("입장")),
                                          ],
                                        ),
                                      );
                                      if (input == null) return;
                                      if (input != room.password) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text("입장 실패"),
                                            content:
                                                const Text("❌ 비밀번호가 틀렸습니다"),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text("확인"),
                                              ),
                                            ],
                                          ),
                                        );
                                        return;
                                      }
                                    }

                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => ChatPage(
                                                roomId: room.id.toString(),
                                                roomName: room.name,
                                              )),
                                    );

                                    // 🔥 ChatPage에서 돌아왔을 때 처리
                                    if (result != null &&
                                        result['shouldRefresh'] == true) {
                                      final returnedRoomId = result['roomId'];
                                      setState(() {
                                        unreadCounts[returnedRoomId] = 0;
                                      });
                                      await Future.delayed(
                                          const Duration(milliseconds: 200));
                                      await _loadUnreadCounts();
                                    }
                                  },

                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (room.createId == userId ||
                                          role == "ROLE_MASTER")
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () async {
                                            final confirm = await showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text("삭제 확인"),
                                                content:
                                                    const Text("정말 삭제하시겠습니까?"),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, false),
                                                      child: const Text("취소")),
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, true),
                                                      child: const Text("삭제")),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              await ChatApiService.deleteRoom(
                                                  room.id);
                                              _fetchRooms(); // 새로고침
                                            }
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _isMessageClientConnected = false;

    if (_isMessageClientConnected) {
      messageClient.deactivate();
    }

    super.dispose();
  }
}
