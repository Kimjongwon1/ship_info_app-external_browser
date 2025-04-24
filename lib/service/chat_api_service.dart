import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatApiService {
  static const String baseUrl = 'http://192.168.219.41:8080/api/chat';
  static Future<List<String>> fetchRoomList() async {
    final response = await http.get(Uri.parse('$baseUrl/rooms'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => e.toString()).toList();
    } else {
      throw Exception('채팅방 목록 조회 실패');
    }
  }

  /// 모든 메시지 불러오기
  static Future<List<Map<String, dynamic>>> fetchChatHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/history'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  /// ✅ roomId 기반 메시지 불러오기
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
}
