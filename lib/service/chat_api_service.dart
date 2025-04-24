import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatApiService {
  static const String baseUrl = 'http://10.0.2.2:8080'; // 에뮬레이터 기준

  static Future<List<Map<String, dynamic>>> fetchChatHistory() async {
    final response = await http.get(Uri.parse('$baseUrl/api/chat/history'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data
          .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
          .toList();
    } else {
      throw Exception('Failed to load chat history');
    }
  }
}
