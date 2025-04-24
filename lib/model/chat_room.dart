class ChatRoom {
  final int id;
  final String name;

  ChatRoom({required this.id, required this.name});

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'],
    );
  }
}
