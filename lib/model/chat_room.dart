class ChatRoom {
  final int id;
  final String name;
  final String? password;

  ChatRoom({
    required this.id,
    required this.name,
    this.password,
  });

  bool get hasPassword => password != null && password!.isNotEmpty;

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'],
      password: json['password'],
    );
  }
}
