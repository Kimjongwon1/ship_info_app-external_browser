import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ship_info_app/screen/chat_room_list_page.dart';

import '../../provider/auth_provider.dart';
import '../../widget/button.dart';
import '../../widget/input_field.dart';
import '../../widget/toast.dart';
import 'register_page.dart'; // ✅ 회원가입 페이지 import

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
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
            const SizedBox(height: 16),
            Button(
              text: '로그인',
              onPressed: () async {
                  print("🔥 로그인 버튼 눌림");

                final result = await ref.read(authProvider.notifier).login(
                      usernameController.text,
                      passwordController.text,
                    );
                      print("✅ 로그인 result: $result");

                if (result) {
              Toast.show(context, '로그인 성공');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChatRoomListPage()), // ✅ 여기로 이동
                  );
                } else {
                 Toast.show(context, '로그인 실패');

                }
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                );
              },
              child: const Text('회원가입'),
            ),
          ],
        ),
      ),
    );
  }
}
