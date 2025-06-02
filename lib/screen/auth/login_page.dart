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

                  // 🚀 로딩 다이얼로그 표시
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const AlertDialog(
                      content: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text("로그인 중..."),
                        ],
                      ),
                    ),
                  );

                  try {
                    final result = await ref.read(authProvider.notifier).login(
                          usernameController.text,
                          passwordController.text,
                        );

                    // 🚀 로딩 다이얼로그 닫기
                    Navigator.pop(context);

                    print('✅ 로그인 결과: $result');
                    if (result) {
                      Toast.show(context, '로그인 성공');
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const ShipListPage()),
                      );
                    } else {
                      // 🚀 인증 실패 (아이디/비밀번호 틀림)
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
                  } catch (e) {
                    // 🚀 로딩 다이얼로그 닫기
                    Navigator.pop(context);

                    print('❌ 로그인 에러: $e');

                    // 🚀 에러 타입별 처리
                    String errorMessage;
                    String errorTitle;

                    final errorString = e.toString().toLowerCase();

                    if (errorString.contains('socket') ||
                        errorString.contains('network') ||
                        errorString.contains('connection') ||
                        errorString.contains('timeout') ||
                        errorString.contains('host lookup') ||
                        errorString.contains('unreachable')) {
                      // 🌐 서버 연결 실패
                      errorTitle = "서버 연결 실패";
                      errorMessage =
                          "서버에 연결할 수 없습니다.\n네트워크 상태를 확인하거나\n잠시 후 다시 시도해주세요.";
                    } else if (errorString.contains('timeout')) {
                      // ⏰ 요청 시간 초과
                      errorTitle = "요청 시간 초과";
                      errorMessage = "서버 응답이 지연되고 있습니다.\n잠시 후 다시 시도해주세요.";
                    } else if (errorString.contains('format') ||
                        errorString.contains('parse')) {
                      // 📊 데이터 형식 오류
                      errorTitle = "서버 오류";
                      errorMessage = "서버에서 잘못된 응답을 받았습니다.\n잠시 후 다시 시도해주세요.";
                    } else {
                      // ❓ 기타 알 수 없는 오류
                      errorTitle = "오류 발생";
                      errorMessage = "예상치 못한 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.";
                    }

                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text(errorTitle),
                        content: Text(errorMessage),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("확인"),
                          ),
                          // 🚀 재시도 버튼 추가
                          if (errorString.contains('network') ||
                              errorString.contains('connection') ||
                              errorString.contains('timeout'))
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                                // 재시도 로직 (현재 함수 다시 호출)
                                Future.delayed(
                                    const Duration(milliseconds: 100), () {
                                  // 동일한 로그인 로직 재실행
                                });
                              },
                              child: const Text("재시도"),
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
