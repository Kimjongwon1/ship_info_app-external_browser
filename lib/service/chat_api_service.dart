import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/chat_room.dart';

class ChatApiService {
  static const String baseUrl = 'http://192.168.219.41:8080/api/chat';

  static const String roomBaseUrl = 'http://192.168.219.41:8080/api/room';

  static Future<List<ChatRoom>> fetchRoomList() async {
    final response = await http.get(Uri.parse('$roomBaseUrl/list'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => ChatRoom.fromJson(e)).toList();
    } else {
      throw Exception('채팅방 목록 조회 실패');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/history'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchChatHistoryByRoom(
      String roomId) async {
    final response = await http.get(Uri.parse('$baseUrl/history/$roomId'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load chat history by room');
    }
  }

  static Future<int> fetchParticipantCount(String roomId) async {
    final url = Uri.parse('$baseUrl/room/$roomId/count');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      throw Exception("Failed to fetch participant count");
    }
  }

  /// ✅ 이름만 받아서 방 생성
  static Future<void> createRoom(String name) async {
    final url = Uri.parse('$roomBaseUrl/create');

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: utf8.encode(jsonEncode({"name": name})),
    );

    if (response.statusCode != 200) {
      throw Exception("채팅방 생성 실패: ${response.body}");
    }
  }

  static Future<void> deleteRoom(int roomId) async {
    final url = Uri.parse('$roomBaseUrl/delete/$roomId');
    final response = await http.delete(url);

    if (response.statusCode != 200) {
      throw Exception("삭제 실패: ${response.body}");
    }
  }
}
