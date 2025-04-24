import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

class ChatSocketService {
  static final ChatSocketService _instance = ChatSocketService._internal();
  factory ChatSocketService() => _instance;

  ChatSocketService._internal();

  StompClient? stompClient;

  void connect(void Function(Map<String, dynamic>) onMessageReceived) {
    stompClient = StompClient(
      config: StompConfig.SockJS(
        url: 'http://10.0.2.2:8080/ws-chat', // Android 에뮬레이터용
        onConnect: (StompFrame frame) {
          print('✅ WebSocket 연결됨');
          stompClient!.subscribe(
            destination: '/topic/chat',
            callback: (frame) {
              if (frame.body != null) {
                final data = frame.body!;
                print('📥 수신 메시지: $data');
                onMessageReceived.call({'payload': data});
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => print('❌ WebSocket 오류: $error'),
      ),
    );

    stompClient!.activate();
  }

  void disconnect() {
    stompClient?.deactivate();
  }
}
