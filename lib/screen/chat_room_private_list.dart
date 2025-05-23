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

  Map<String, int> participantCache = {};
  bool isLoading = true;
  String searchKeyword = "";
  String role = '';
  String userId = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchPrivateRooms();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? '';
      userId = prefs.getString('userId') ?? '';
    });
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
      filteredRooms =
          allRooms.where((room) => room.name.contains(searchKeyword)).toList();
    });
  }

  void _showUserSelectDialog() async {
    try {
      final users = await ChatApiService.fetchAllUsers();
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('대화할 유저 선택'),
          content: SizedBox(
            width: 300,
            height: 400,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (_, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user.name),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePrivateRoomDialog(user);
                  },
                );
              },
            ),
          ),
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
    final nameController = TextEditingController(text: inviteUser.name);
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
              decoration: const InputDecoration(labelText: "방 이름"),
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
                  name,
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
                      roomName: name,
                      isPrivate: true,
                    ),
                  ),
                ).then((_) {
                  // ✅ 채팅방에서 돌아온 후 목록 자동 새로고침
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
        url: 'https://c341-118-131-64-204.ngrok-free.app/ws-chat',
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
                        hintText: "비공개 방 이름 검색",
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
                                  "비공개 채팅방이 없습니다",
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "우상단 + 버튼으로 새 비공개 방을 만들어보세요",
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

                              return Card(
                                elevation: 3,
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.lock,
                                    color: Colors.red,
                                    size: 28,
                                  ),
                                  title: Text(
                                    room.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  onTap: () async {
                                    print(
                                        "✅ 입장 성공: roomId=${room.id}, roomName=${room.name}");

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          roomId: room.id.toString(),
                                          roomName: room.name,
                                          isPrivate: true,
                                        ),
                                      ),
                                    );
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
                                                title: const Text("비공개 방 삭제"),
                                                content: Text(
                                                    "'${room.name}' 방을 정말 삭제하시겠습니까?"),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child: const Text("취소"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child: const Text("삭제"),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              try {
                                                await ChatApiService.deleteRoom(
                                                    room.id);
                                                _fetchPrivateRooms();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  const SnackBar(
                                                      content: Text(
                                                          "비공개 방이 삭제되었습니다")),
                                                );
                                              } catch (e) {
                                                print('❌ 방 삭제 오류: $e');
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content:
                                                          Text('삭제 실패: $e')),
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
}
