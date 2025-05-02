import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

final authProvider = StateNotifierProvider<AuthNotifier, bool>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<bool> {
  AuthNotifier() : super(false);

  Future<bool> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('http://192.168.219.150:8080/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    print("📡 응답코드: ${response.statusCode}");
    print("📡 응답본문: ${response.body}");
    if (response.statusCode == 200) {
      final token = response.headers['authorization']?.replaceFirst('Bearer ', '');
          print("🪪 JWT 토큰: $token");
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt', token);
        state = true;
        return true;
      }
    }

    return false;
  }
}
