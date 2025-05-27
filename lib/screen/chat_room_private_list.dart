import 'dart:convert'; // JSON 파싱을 위해 추가

import 'package:CHAT_SHIRE/model/private_chat_room.dart';
import 'package:CHAT_SHIRE/model/user.dart';
import 'package:CHAT_SHIRE/util/route_path.dart';
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
  Map<String, String> roomDisplayNames = {}; // roomId -> displayName 매핑

  Map<String, int> participantCache = {};
  bool isLoading = true;
  String searchKeyword = "";
  String role = '';
  String userId = '';
  late StompClient roomInviteClient; // 방 초대 알림용 클라이언트

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchPrivateRooms();
    _subscribeToRoomInvitations(); // 초대 알림 구독 추가
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? '';
      userId = prefs.getString('userId') ?? '';
    });
  }

  // 개인 채팅방 초대 알림 구독
  // 개인 채팅방 초대 알림 구독
  void _subscribeToRoomInvitations() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('userId') ?? '';

    if (currentUserId.isEmpty) return;

    roomInviteClient = StompClient(
      config: StompConfig.SockJS(
        url: 'https://1970-118-131-64-204.ngrok-free.app/ws-chat',
        onConnect: (StompFrame frame) {
          print('✅ 방 초대 알림 WebSocket 연결됨');

          // 나에게 온 초대 알림 구독
          roomInviteClient.subscribe(
            destination: '/sub/private-room/invite/$currentUserId',
            callback: (frame) {
              print('📨 개인 채팅방 알림: ${frame.body}');

              try {
                // JSON 파싱 - 한 번만!
                final Map<String, dynamic> data =
                    jsonDecode(frame.body ?? '{}');

                // ✅ 삭제 알림인 경우
                if (data['action'] == 'delete') {
                  final deletedRoomId = data['roomId'].toString();
                  print('🗑 삭제 알림 수신 → roomId: $deletedRoomId');

                  setState(() {
                    allRooms.removeWhere(
                        (room) => room.id.toString() == deletedRoomId);
                    filteredRooms.removeWhere(
                        (room) => room.id.toString() == deletedRoomId);
                    roomDisplayNames.remove(deletedRoomId);
                  });

                  // 삭제 알림 표시
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('채팅방이 삭제되었습니다'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }

                  return; // ⭐️ 중요! 여기서 함수 종료
                }

                // ✅ 방 생성 알림 처리 (삭제가 아닌 경우에만 실행됨)
                print('🏠 방 생성 알림 처리');

                // null 체크 추가
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

                // 실시간으로 방 목록에 추가
                setState(() {
                  // 중복 체크
                  if (!allRooms.any((room) => room.id == newRoom.id)) {
                    allRooms.add(newRoom);

                    // 표시 이름 설정
                    _updateRoomDisplayName(newRoom);

                    // 필터 재적용
                    _applyFilter();
                  }
                });

                // 알림 표시 (본인이 만든 방은 알림 표시 안 함)
                if (mounted && newRoom.createId != currentUserId) {
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
        },
        onWebSocketError: (error) => print('❌ 방 초대 알림 WebSocket 오류: $error'),
      ),
    );
    roomInviteClient.activate();
  }

  // 단일 방의 표시 이름 업데이트
  void _updateRoomDisplayName(PrivateChatRoom room) async {
    if (room.createId == userId && room.inviteId == userId) {
      roomDisplayNames[room.id.toString()] = "나와의 채팅";
    } else if (room.inviteId == userId) {
      // 초대한 사람의 이름 가져오기
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

      // 모든 유저 정보를 가져와서 이름을 매핑
      final users = await ChatApiService.fetchAllUsers();
      final userMap = {for (var user in users) user.id: user.name};

      // 각 방에 대해 표시할 이름을 설정
      roomDisplayNames.clear();
      for (var room in visibleRooms) {
        if (room.createId == userId && room.inviteId == userId) {
          // 생성자와 초대자가 모두 나인 경우: 나와의 채팅
          roomDisplayNames[room.id.toString()] = "나와의 채팅";
        } else if (room.inviteId == userId) {
          // 내가 초대받은 경우: 방을 만든 사람의 이름을 표시
          final creatorName = userMap[room.createId] ?? room.createId;
          roomDisplayNames[room.id.toString()] = "$creatorName님과의 1대1 채팅방";
        } else {
          // 내가 만든 경우: 기존 방 이름 유지
          roomDisplayNames[room.id.toString()] = room.name;
        }
      }

      setState(() {
        allRooms = visibleRooms;
        _applyFilter();
      });

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
    // 먼저 해당 유저와의 채팅방이 이미 있는지 확인
    PrivateChatRoom? existingRoom;
    try {
      existingRoom = allRooms.firstWhere((room) =>
          (room.createId == userId && room.inviteId == inviteUser.id) ||
          (room.createId == inviteUser.id && room.inviteId == userId));
    } catch (e) {
      // 찾지 못한 경우 null로 유지
      existingRoom = null;
    }

    if (existingRoom != null) {
      // 이미 채팅방이 있으면 안내하고 바로 입장 옵션 제공
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
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      roomId: existingRoom!.id.toString(),
                      roomName: displayName,
                      isPrivate: true,
                    ),
                  ),
                );
              },
              child: const Text("채팅방 입장"),
            ),
          ],
        ),
      );
      return;
    }

    // 기존 방이 없는 경우에만 새로 생성
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      roomId: roomId.toString(),
                      roomName:
                          name.isEmpty ? "${inviteUser.name}님과의 1대1 채팅방" : name,
                      isPrivate: true,
                    ),
                  ),
                ).then((_) {
                  _fetchPrivateRooms();
                });
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
        url: 'https://1970-118-131-64-204.ngrok-free.app/ws-chat',
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
              onPressed: _fetchPrivateRooms,
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

                              return Card(
                                elevation: 3,
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.lock,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                  title: Text(
                                    displayName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  onTap: () async {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          roomId: room.id.toString(),
                                          roomName: displayName,
                                          isPrivate: true,
                                        ),
                                      ),
                                    );
                                  },
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () async {
                                          final confirm = await showDialog(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text("1대1 채팅방 삭제"),
                                              content: Text(
                                                  "'$displayName' 방을 정말 삭제하시겠습니까?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text("취소"),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text("삭제"),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            try {
                                              await ChatApiService
                                                  .privatedeleteRoom(room.id);
                                              _fetchPrivateRooms();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "1대1 채팅방이 삭제되었습니다")),
                                              );
                                            } catch (e) {
                                              print('❌ 방 삭제 오류: $e');
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text('삭제 실패: $e')),
                                              );
                                            }
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
    // STOMP 클라이언트 정리
    if (isStompConnected) {
      stompClient.deactivate();
    }
    roomInviteClient.deactivate();
    super.dispose();
  }
}
