class ChatRoom {
  final int id;
  final String name;
  final String? password;
  final String? createId;

  ChatRoom({
    required this.id,
    required this.name,
    required this.createId,
    this.password,
  });

  bool get hasPassword => password != null && password!.isNotEmpty;

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'],
      password: json['password'],
      createId: json['createId'],
    );
  }
}
