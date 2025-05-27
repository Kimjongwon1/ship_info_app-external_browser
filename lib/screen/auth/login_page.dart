import 'package:CHAT_SHIRE/screen/chat_room_list_page.dart';
import 'package:CHAT_SHIRE/screen/ship_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/auth_provider.dart';
import '../../widget/button.dart';
import '../../widget/input_field.dart';
import '../../widget/toast.dart';
import 'register_page.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Padding(
            padding: EdgeInsets.only(left: 10),
            child: Text('로그인'),
          ),
          centerTitle: true,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                }),
          ],
        ),
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
                  if (usernameController.text.isEmpty ||
                      passwordController.text.isEmpty) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("로그인 실패"),
                        content: const Text("아이디 또는 비밀번호를 입력하세요"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("확인"),
                          ),
                        ],
                      ),
                    );
                    return;
                  }

                  final result = await ref.read(authProvider.notifier).login(
                        usernameController.text,
                        passwordController.text,
                      );
                  print('✅ 로그인 결과: $result');
                  if (result) {
                    Toast.show(context, '로그인 성공');
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ShipListPage()),
                    );
                  } else {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("로그인 실패"),
                        content: const Text("아이디 또는 비밀번호가 잘못되었습니다"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("확인"),
                          ),
                        ],
                      ),
                    );
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
      ),
    );
  }
}
