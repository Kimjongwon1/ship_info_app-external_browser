class PrivateChatRoom {
  final int id;
  final String name;
  final String? password;
  final String createId;
  final String inviteId;

  PrivateChatRoom({
    required this.id,
    required this.name,
    required this.createId,
    required this.inviteId,
    this.password,
  });

  factory PrivateChatRoom.fromJson(Map<String, dynamic> json) {
    return PrivateChatRoom(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      password: json['password'],
      createId: json['createId'] ?? '',
      inviteId: json['inviteId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'createId': createId,
      'inviteId': inviteId,
    };
  }
}
