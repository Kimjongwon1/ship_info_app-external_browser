import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../widget/button.dart';
import '../../widget/input_field.dart';
import '../../widget/toast.dart';

class RegisterPage extends ConsumerWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            InputField(
              hint: '아이디',
              controller: usernameController,
            ),
            InputField(
              hint: '비밀번호',
              controller: passwordController,
              obscureText: true,
            ),
            InputField(
              hint: '비밀번호 확인',
              controller: confirmPasswordController,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            Button(
              text: '회원가입',
              onPressed: () async {
                print("🔥 회원가입 버튼 눌림");
                final id = usernameController.text;
                final pw = passwordController.text;
                final confirmPw = confirmPasswordController.text;

                if (id.isEmpty || pw.isEmpty || confirmPw.isEmpty) {
                  Toast.show(context, '모든 항목을 입력하세요');
                  return;
                }

                if (pw != confirmPw) {
                  Toast.show(context, '비밀번호가 일치하지 않습니다');
                  return;
                }
                print("📡 요청 보냄");

                final response = await http.post(
                  Uri.parse('http://192.168.219.150:8080/api/register'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'username': id, 'password': pw}),
                );

                if (response.statusCode == 200) {
                  Toast.show(context, '회원가입 성공! 로그인하세요');
                  Navigator.pop(context); // 로그인 화면으로 돌아감
                } else {
                  Toast.show(context, '회원가입 실패');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
