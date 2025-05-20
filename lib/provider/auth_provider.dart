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
      Uri.parse('https://c095-118-131-64-204.ngrok-free.app/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    // print("📡 응답코드: ${response.statusCode}");
    // print("📡 응답본문: ${response.body}");
    if (response.statusCode == 200) {
      final token =
          response.headers['authorization']?.replaceFirst('Bearer ', '');
      final jsonBody = jsonDecode(response.body);
      final role = jsonBody['role'];

      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt', token);
        if (role != null) {
          await prefs.setString('role', role);
        }
        state = true;
        return true;
      }
    }

    return false;
  }
}
