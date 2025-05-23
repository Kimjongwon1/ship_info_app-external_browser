import 'package:CHAT_SHIRE/model/chat_room.dart';
import 'package:CHAT_SHIRE/util/route_path.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../service/chat_api_service.dart';
import '../service/chat_stomp_service.dart';
import 'chat_page.dart';

class ChatRoomListPage extends StatefulWidget {
  const ChatRoomListPage({super.key});

  @override
  State<ChatRoomListPage> createState() => _ChatRoomListPageState();
}

class _ChatRoomListPageState extends State<ChatRoomListPage> {
  List<ChatRoom> allRooms = [];
  List<ChatRoom> filteredRooms = [];
  Map<String, int> participantCache = {};
  bool isLoading = true;
  String searchKeyword = "";
  String role = '';
  String userId = '';
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchRooms();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? 'UnknownUser';

    // print('🔍 SharedPreferences에서 가져온 username: $username');
    // print('🔍 UTF-8 바이트: ${utf8.encode(username)}');
    setState(() {
      role = prefs.getString('role') ?? '';
      userId = prefs.getString('userId') ?? '';
    });
  }

  Future<void> _fetchRooms() async {
    setState(() => isLoading = true);
    try {
      final rooms = await ChatApiService.fetchRoomList();
      setState(() {
        allRooms = rooms;
        _applyFilter();
      });
      _fetchParticipantsForRooms(rooms);

      connectStompForRoomList((roomId, count) {
        setState(() {
          participantCache[roomId] = count;
        });
      });
    } catch (e) {
      print("❌ 채팅방 목록 오류: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchParticipantsForRooms(List<ChatRoom> rooms) async {
    for (var room in rooms) {
      final roomId = room.id.toString(); // 🔄 int → String
      final count = await ChatApiService.fetchParticipantCount(roomId);
      setState(() {
        participantCache[roomId] = count;
      });
    }
  }

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

  void connectStompForRoomList(
      Function(String roomId, int count) onParticipantUpdate) {
    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: 'https://c341-118-131-64-204.ngrok-free.app/ws-chat',
        onConnect: (StompFrame frame) {
          isStompConnected = true;
          // 🔥 각 방에 대한 참여자 수 구독
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
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredRooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 18),
                      itemBuilder: (context, index) {
                        final room = filteredRooms[index];
                        final roomId = room.id.toString(); // int -> String 변환
                        final roomName = room.name;
                        final count = participantCache[roomId];
                        final countText = (count != null)
                            ? "👥 $count명 참여중"
                            : "참여자 수 로딩 중...";
                        // 🔍 디버깅용 로그 추가

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              room.password != null && room.password!.isNotEmpty
                                  ? Icons.lock_outline
                                  : Icons.chat_bubble_outline,
                              color: room.password != null &&
                                      room.password!.isNotEmpty
                                  ? Colors.red
                                  : Colors.blue,
                            ),

                            title: Text(room.name),
                            onTap: () async {
                              // print(
                              //     "🧪 방 이름: ${room.name}, 비번: ${room.password}");

                              if (role == "ROLE_MASTER" ||
                                  room.createId == userId) {
                                // 마스터는 비밀번호 없이 입장
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                            roomId: room.id.toString(),
                                            roomName: room.name,
                                          )),
                                );
                                return;
                              }
                              if (room.password != null &&
                                  room.password!.isNotEmpty) {
                                final controller = TextEditingController();
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
                                          onPressed: () =>
                                              Navigator.pop(context, null),
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
                                      content: const Text("❌ 비밀번호가 틀렸습니다"),
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

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                          roomId: room.id.toString(),
                                          roomName: room.name,
                                        )),
                              );
                            },

                            // subtitle: Text(countText),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // IconButton(
                                //   icon: const Icon(Icons.arrow_forward_ios,
                                //       size: 16),
                                //   onPressed: () {
                                //     Navigator.push(
                                //       context,
                                //       MaterialPageRoute(
                                //         builder: (_) =>
                                //             ChatPage(roomId: room.id.toString()),
                                //       ),
                                //     );
                                //   },
                                // ),
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
                                          content: const Text("정말 삭제하시겠습니까?"),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text("취소")),
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
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
}
