import 'dart:convert';

import 'package:CHAT_SHIRE/model/private_chat_room.dart';
import 'package:CHAT_SHIRE/model/user.dart';
import 'package:CHAT_SHIRE/service/unread_message_manager.dart';
import 'package:CHAT_SHIRE/util/route_path.dart';
import 'package:chat_config/chat_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../service/chat_api_service.dart';
import '../service/chat_stomp_service.dart';
import 'chat_page.dart';

class ChatRoomPrivateListPage extends StatefulWidget {
  const ChatRoomPrivateListPage({super.key});

  @override
  State<ChatRoomPrivateListPage> createState() =>
      _ChatRoomPrivateListPageState();
}

class _ChatRoomPrivateListPageState extends State<ChatRoomPrivateListPage> {
  List<PrivateChatRoom> allRooms = [];
  List<PrivateChatRoom> filteredRooms = [];
  Map<String, String> roomDisplayNames = {};
  Map<String, int> participantCache = {};
  Map<String, int> unreadCounts = {}; // 🔥 안읽은 메시지 개수 저장
  Map<String, String> lastMessages = {}; // 🔥 마지막 메시지 저장
  Map<String, String> lastMessageTimes = {}; // 🔥 마지막 메시지 시간 저장

  bool isLoading = true;
  String searchKeyword = "";
  String role = '';
  String userId = '';
  String username = ''; // ✅ username 추가
  late StompClient roomInviteClient;
  bool _isInviteClientConnected = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchPrivateRooms();
    _subscribeToRoomInvitations();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? '';
      userId = prefs.getString('userId') ?? '';
      username = prefs.getString('username') ?? ''; // ✅ username 로드
    });
  }

  // 🔥 안읽은 메시지 개수 및 마지막 메시지 로드 (UnreadMessageManager 사용)
  Future<void> _loadUnreadCounts() async {
    if (allRooms.isEmpty) return;

    for (var room in allRooms) {
      final roomId = room.id.toString();

      try {
        // 🔥 UnreadMessageManager 사용해서 안읽은 메시지 개수 조회
        final unreadCount =
            await UnreadMessageManager.getPrivateUnreadCount(roomId);

        // 🔥 UnreadMessageManager 사용해서 마지막 메시지 정보 조회
        final lastMessageData =
            await UnreadMessageManager.getPrivateLastMessage(roomId);

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

  // ✅ 메시지가 내가 보낸 것인지 체크하는 함수
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

  // ✅ 새로운 함수: 모든 방의 실시간 메시지 구독
  void _subscribeToAllRoomMessages() {
    print('🔔 실시간 메시지 구독 시작 - 방 개수: ${allRooms.length}');

    for (var room in allRooms) {
      final roomId = room.id.toString();
      print('📡 방 $roomId 실시간 메시지 구독');

      roomInviteClient.subscribe(
        destination: '/sub/chat/private/$roomId',
        callback: (frame) {
          if (!mounted) return;

          try {
            final messageData = jsonDecode(frame.body ?? '{}');
            final sender =
                messageData['sender'] ?? messageData['senderId'] ?? '';
            final senderName = messageData['senderName'] ?? '';

            print('🔍 실시간 메시지 수신 - 방: $roomId');
            print('📤 보낸이: $sender, 보낸이명: $senderName');
            print('📤 현재유저: $userId, 현재유저명: $username');
            print('📋 메시지 데이터: $messageData');

            // ✅ 더 엄격한 sender 체크
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

  void _subscribeToRoomInvitations() async {
    if (_isInviteClientConnected) {
      print('⚠️ 이미 초대 알림 클라이언트가 연결되어 있습니다');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId') ?? '';

    if (currentUserId.isEmpty) return;

    roomInviteClient = StompClient(
      config: StompConfig.SockJS(
        url: ApiConfig.wsUrl,
        onConnect: (StompFrame frame) {
          print('✅ 방 초대 알림 WebSocket 연결됨');
          _isInviteClientConnected = true;

          // 나에게 온 초대 알림 구독
          roomInviteClient.subscribe(
            destination: '/sub/private-room/invite/$currentUserId',
            callback: (frame) {
              print('📨 개인 채팅방 알림: ${frame.body}');

              if (!mounted) return;

              try {
                final Map<String, dynamic> data =
                    jsonDecode(frame.body ?? '{}');

                if (data['action'] == 'delete') {
                  final deletedRoomId = data['roomId'].toString();
                  print('🗑 삭제 알림 수신 → roomId: $deletedRoomId');

                  setState(() {
                    allRooms.removeWhere(
                        (room) => room.id.toString() == deletedRoomId);
                    filteredRooms.removeWhere(
                        (room) => room.id.toString() == deletedRoomId);
                    roomDisplayNames.remove(deletedRoomId);
                    // 🔥 안읽은 메시지 관련 데이터도 삭제
                    unreadCounts.remove(deletedRoomId);
                    lastMessages.remove(deletedRoomId);
                    lastMessageTimes.remove(deletedRoomId);
                  });

                  return;
                }

                print('🏠 방 생성 알림 처리');

                if (data['id'] == null) {
                  print('❌ 방 ID가 null입니다');
                  return;
                }

                final newRoom = PrivateChatRoom(
                  id: data['id'] is int
                      ? data['id']
                      : int.tryParse(data['id'].toString()) ?? 0,
                  name: data['name'] ?? '',
                  password: data['password'] ?? '',
                  createId: data['createId'] ?? '',
                  inviteId: data['inviteId'] ?? '',
                );

                setState(() {
                  if (!allRooms.any((room) => room.id == newRoom.id)) {
                    allRooms.add(newRoom);
                    _updateRoomDisplayName(newRoom);
                    // 🔥 새 방의 안읽은 메시지 초기화
                    final roomId = newRoom.id.toString();
                    unreadCounts[roomId] = 0;
                    lastMessages[roomId] = '';
                    lastMessageTimes[roomId] = '';
                    _applyFilter();

                    // ✅ 새 방 추가시 실시간 메시지 구독
                    roomInviteClient.subscribe(
                      destination: '/sub/chat/private/$roomId',
                      callback: (frame) {
                        if (!mounted) return;

                        try {
                          final messageData = jsonDecode(frame.body ?? '{}');

                          print('🔍 실시간 메시지 수신 - 새 방: $roomId');
                          final isMyMessage = _isMyMessage(messageData);
                          print('🔍 새 방 내 메시지 여부: $isMyMessage');

                          if (!isMyMessage) {
                            setState(() {
                              unreadCounts[roomId] =
                                  (unreadCounts[roomId] ?? 0) + 1;
                              lastMessages[roomId] =
                                  UnreadMessageManager.cleanMessageText(
                                      messageData['message'] ?? '');
                              lastMessageTimes[roomId] =
                                  UnreadMessageManager.formatTime(
                                      messageData['timestamp']);
                            });
                            print('📈 새 방 안읽은 메시지 증가: ${unreadCounts[roomId]}');
                          }
                        } catch (e) {
                          print('❌ 새 방 실시간 메시지 처리 오류: $e');
                        }
                      },
                    );
                  }
                });

                if (newRoom.createId != currentUserId) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${roomDisplayNames[newRoom.id.toString()] ?? newRoom.name}이 생성되었습니다'),
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: '입장',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                roomId: newRoom.id.toString(),
                                roomName:
                                    roomDisplayNames[newRoom.id.toString()] ??
                                        newRoom.name,
                                isPrivate: true,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                print('❌ 방 알림 파싱 오류: $e');
                print('📋 받은 데이터: ${frame.body}');
              }
            },
          );

          // ✅ WebSocket 연결 후 실시간 메시지 구독 설정
          if (allRooms.isNotEmpty) {
            _subscribeToAllRoomMessages();
          }
        },
        onDisconnect: (frame) {
          print('❌ 방 초대 알림 WebSocket 연결 해제됨');
          _isInviteClientConnected = false;
        },
        onWebSocketError: (error) {
          print('❌ 방 초대 알림 WebSocket 오류: $error');
          _isInviteClientConnected = false;
        },
      ),
    );
    roomInviteClient.activate();
  }

  void _updateRoomDisplayName(PrivateChatRoom room) async {
    if (room.createId == userId && room.inviteId == userId) {
      roomDisplayNames[room.id.toString()] = "나와의 채팅";
    } else if (room.inviteId == userId) {
      try {
        final users = await ChatApiService.fetchAllUsers();
        final creator = users.firstWhere((user) => user.id == room.createId,
            orElse: () => User(id: room.createId, name: room.createId));
        roomDisplayNames[room.id.toString()] = "${creator.name}님과의 1대1 채팅방";
      } catch (e) {
        roomDisplayNames[room.id.toString()] = "${room.createId}님과의 1대1 채팅방";
      }
    } else {
      roomDisplayNames[room.id.toString()] = room.name;
    }
  }

  Future<void> _fetchPrivateRooms() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final rooms = await ChatApiService.fetchPrivateRoomList();
      final visibleRooms = rooms
          .where((room) => room.createId == userId || room.inviteId == userId)
          .toList();

      final users = await ChatApiService.fetchAllUsers();
      final userMap = {for (var user in users) user.id: user.name};

      roomDisplayNames.clear();
      for (var room in visibleRooms) {
        if (room.createId == userId && room.inviteId == userId) {
          roomDisplayNames[room.id.toString()] = "나와의 채팅";
        } else if (room.inviteId == userId) {
          final creatorName = userMap[room.createId] ?? room.createId;
          roomDisplayNames[room.id.toString()] = "$creatorName님과의 1대1 채팅방";
        } else {
          roomDisplayNames[room.id.toString()] = room.name;
        }
      }

      setState(() {
        allRooms = visibleRooms;
        _applyFilter();
      });

      // 🔥 안읽은 메시지 개수 로드
      await _loadUnreadCounts();

      // ✅ 방 목록 로드 후 실시간 메시지 구독 설정
      if (_isInviteClientConnected) {
        _subscribeToAllRoomMessages();
      }

      connectStompForRoomList((roomId, count) {
        setState(() {
          participantCache[roomId] = count;
        });
      });
    } catch (e) {
      print("❌ 개인 채팅방 목록 오류: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      filteredRooms = allRooms.where((room) {
        final displayName = roomDisplayNames[room.id.toString()] ?? room.name;
        return displayName.contains(searchKeyword);
      }).toList();
    });
  }

  void _showUserSelectDialog() async {
    try {
      final users = await ChatApiService.fetchAllUsers();
      String searchQuery = '';

      showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final filteredUsers = users.where((user) {
              if (searchQuery.isEmpty) return true;
              return user.name
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  user.id.toLowerCase().contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('대화할 유저 선택'),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: '이름 또는 ID로 검색...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${filteredUsers.length}명의 유저',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (filteredUsers.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                '검색 결과가 없습니다',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredUsers.length,
                          itemBuilder: (_, index) {
                            final user = filteredUsers[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: Colors.blue.shade800,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  user.id,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.chat_bubble_outline,
                                  color: Colors.blue.shade400,
                                ),
                                onTap: () {
                                  Navigator.pop(context);
                                  _showCreatePrivateRoomDialog(user);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      print('❌ 유저 목록 조회 실패: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("유저 목록 불러오기 실패")),
      );
    }
  }

  void _showCreatePrivateRoomDialog(User inviteUser) {
    PrivateChatRoom? existingRoom;
    try {
      existingRoom = allRooms.firstWhere((room) =>
          (room.createId == userId && room.inviteId == inviteUser.id) ||
          (room.createId == inviteUser.id && room.inviteId == userId));
    } catch (e) {
      existingRoom = null;
    }

    if (existingRoom != null) {
      final displayName =
          roomDisplayNames[existingRoom.id.toString()] ?? existingRoom.name;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("알림"),
          content: Text("${inviteUser.name}님과의 채팅방이 이미 존재합니다."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("취소"),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);

                // ✅ 채팅방 입장 시 읽음 처리 (UnreadMessageManager 사용)
                final roomId = existingRoom!.id.toString();
                await UnreadMessageManager.markAsRead(roomId);
                setState(() {
                  unreadCounts[roomId] = 0;
                });

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      roomId: existingRoom!.id.toString(),
                      roomName: displayName,
                      isPrivate: true,
                    ),
                  ),
                );

                // ✅ ChatPage에서 돌아왔을 때 결과 처리
                if (result != null && result['shouldRefresh'] == true) {
                  final returnedRoomId = result['roomId'];
                  print('✅ 기존 채팅방에서 돌아옴 - roomId: $returnedRoomId');

                  setState(() {
                    unreadCounts[returnedRoomId] = 0;
                  });

                  await Future.delayed(const Duration(milliseconds: 200));
                  await _loadUnreadCounts();
                  await _fetchPrivateRooms();
                } else {
                  print('🔄 결과 없음 - 전체 새로고침');
                  await Future.delayed(const Duration(milliseconds: 200));
                  await _loadUnreadCounts();
                }
              },
              child: const Text("채팅방 입장"),
            ),
          ],
        ),
      );
      return;
    }

    final nameController =
        TextEditingController(text: "${inviteUser.name}님과의 1대1 채팅방");
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${inviteUser.name}님과 채팅하시겠습니까?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "방 이름",
                helperText: "원하시는 방 이름으로 변경할 수 있습니다",
              ),
              maxLines: 1,
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
              final inviteId = inviteUser.id;

              final prefs = await SharedPreferences.getInstance();
              final createId = prefs.getString('userId') ?? '';

              try {
                final roomId = await ChatApiService.createPrivateRoom(
                  name.isEmpty ? "${inviteUser.name}님과의 1대1 채팅방" : name,
                  password,
                  createId,
                  inviteId,
                );

                Navigator.pop(context);
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      roomId: roomId.toString(),
                      roomName:
                          name.isEmpty ? "${inviteUser.name}님과의 1대1 채팅방" : name,
                      isPrivate: true,
                    ),
                  ),
                );

                // ✅ ChatPage에서 돌아왔을 때 결과 처리
                if (result != null && result['shouldRefresh'] == true) {
                  final returnedRoomId = result['roomId'];
                  print('✅ 새 채팅방에서 돌아옴 - roomId: $returnedRoomId');

                  setState(() {
                    unreadCounts[returnedRoomId] = 0;
                  });

                  await Future.delayed(const Duration(milliseconds: 200));
                  await _fetchPrivateRooms(); // 전체 방 목록 새로고침
                } else {
                  await _fetchPrivateRooms(); // 안전하게 전체 새로고침
                }
              } catch (e) {
                print('🔍 방 생성 요청2 - createId: $createId');
                print('❌ 방 생성 오류: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("생성 실패: $e")),
                );
              }
            },
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  void connectStompForRoomList(
      Function(String roomId, int count) onParticipantUpdate) {
    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: ApiConfig.wsUrl,
        onConnect: (StompFrame frame) {
          isStompConnected = true;
          for (var room in allRooms) {
            final roomId = room.id.toString();
            stompClient.subscribe(
              destination: '/sub/chat/participants/$roomId',
              callback: (frame) {
                final count = int.tryParse(frame.body ?? '');
                if (count != null) {
                  onParticipantUpdate(roomId, count);
                }
              },
            );
          }
        },
        onWebSocketError: (error) => print('❌ WebSocket 오류: $error'),
      ),
    );
    stompClient.activate();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("개인 채팅방"),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.pushNamed(context, RoutePath.shipList);
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _fetchPrivateRooms();
              },
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showUserSelectDialog,
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
                        hintText: "1대1 채팅방 이름 검색",
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
                                Icon(Icons.lock_outline,
                                    size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  "1대1 채팅방이 없습니다",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "우상단 + 버튼으로 새 1대1 채팅방을 만들어보세요",
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
                              final roomId = room.id.toString();
                              final displayName =
                                  roomDisplayNames[roomId] ?? room.name;
                              final unreadCount = unreadCounts[roomId] ?? 0;
                              final lastMessage = lastMessages[roomId] ?? '';
                              final lastTime = lastMessageTimes[roomId] ?? '';

                              return GestureDetector(
                                onTap: () async {
                                  // 🔥 채팅방 입장 시 읽음 처리
                                  await UnreadMessageManager.markAsRead(roomId);
                                  setState(() {
                                    unreadCounts[roomId] = 0;
                                  });

                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        roomId: room.id.toString(),
                                        roomName: displayName,
                                        isPrivate: true,
                                      ),
                                    ),
                                  );

                                  // ✅ ChatPage에서 돌아왔을 때 결과 처리 (새로고침 제거)
                                  if (result != null &&
                                      result['shouldRefresh'] == true) {
                                    final returnedRoomId = result['roomId'];
                                    print(
                                        '✅ 채팅방에서 돌아옴 - roomId: $returnedRoomId (새로고침 요청됨)');

                                    setState(() {
                                      unreadCounts[returnedRoomId] = 0;
                                    });

                                    await Future.delayed(
                                        const Duration(milliseconds: 200));
                                    await _loadUnreadCounts();
                                    await _fetchPrivateRooms();
                                  } else {
                                    // 🔥 새로고침 없이 안읽은 개수만 업데이트
                                    print(
                                        '✅ 채팅방에서 돌아옴 - roomId: $roomId (새로고침 없음)');
                                    setState(() {
                                      unreadCounts[roomId] = 0;
                                    });
                                  }
                                },
                                child: Card(
                                  elevation: 2,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 🔥 메인 콘텐츠 영역 (이름 + 메시지)
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // 채팅방 이름
                                              Text(
                                                displayName,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: unreadCount > 0
                                                      ? FontWeight.bold
                                                      : FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                              // 마지막 메시지
                                              if (lastMessage.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  lastMessage,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: unreadCount > 0
                                                        ? Colors.grey
                                                            .shade700 // 안읽은 메시지가 있으면 조금 더 진하게
                                                        : Colors.grey.shade500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // 🔥 오른쪽 영역 - 높이 증가로 오버플로우 해결
                                        SizedBox(
                                          height: 80, // 🔥 60px → 80px로 증가
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            mainAxisAlignment: MainAxisAlignment
                                                .spaceBetween, // 🔥 공간 균등 분배
                                            children: [
                                              // 🔥 상단: 삭제 버튼
                                              Align(
                                                alignment: Alignment.topRight,
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: IconButton(
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(), // 🔥 제약 조건 제거
                                                    icon: Icon(
                                                      Icons.delete_outline,
                                                      color:
                                                          Colors.grey.shade400,
                                                      size: 16,
                                                    ),
                                                    onPressed: () async {
                                                      final confirm =
                                                          await showDialog(
                                                        context: context,
                                                        builder: (ctx) =>
                                                            AlertDialog(
                                                          title: const Text(
                                                              "채팅방 삭제"),
                                                          content: Text(
                                                              "'$displayName' 방을 삭제하시겠습니까?"),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      ctx,
                                                                      false),
                                                              child: const Text(
                                                                  "취소"),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                      ctx,
                                                                      true),
                                                              child: const Text(
                                                                "삭제",
                                                                style: TextStyle(
                                                                    color: Colors
                                                                        .red),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                      if (confirm == true) {
                                                        try {
                                                          await ChatApiService
                                                              .privatedeleteRoom(
                                                                  room.id);
                                                          _fetchPrivateRooms();
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  "채팅방이 삭제되었습니다"),
                                                            ),
                                                          );
                                                        } catch (e) {
                                                          ScaffoldMessenger.of(
                                                                  context)
                                                              .showSnackBar(
                                                            SnackBar(
                                                                content: Text(
                                                                    '삭제 실패: $e')),
                                                          );
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ),
                                              ),

                                              // 🔥 하단: 시간 + 뱃지 그룹
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // 시간
                                                  if (lastTime.isNotEmpty)
                                                    Text(
                                                      lastTime,
                                                      style: TextStyle(
                                                        fontSize:
                                                            11, // 🔥 크기 축소
                                                        color: Colors
                                                            .grey.shade500,
                                                      ),
                                                    ),

                                                  // 뱃지
                                                  if (unreadCount > 0) ...[
                                                    const SizedBox(
                                                        height: 3), // 🔥 간격 축소
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal:
                                                              6, // 🔥 패딩 축소
                                                          vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth:
                                                            18, // 🔥 최소 크기 축소
                                                        minHeight: 18,
                                                      ),
                                                      child: Text(
                                                        unreadCount > 99
                                                            ? '99+'
                                                            : '$unreadCount',
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize:
                                                              10, // 🔥 폰트 크기 축소
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
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
    _isInviteClientConnected = false;

    if (isStompConnected) {
      stompClient.deactivate();
      isStompConnected = false;
    }

    roomInviteClient.deactivate();
    super.dispose();
  }
}
