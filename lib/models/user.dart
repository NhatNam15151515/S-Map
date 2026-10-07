class User {
  String? id;
  String? username;
  String? email;
  String? avatarUrl;
  String? avatarBase64;
  bool init = false;

  User({
    this.id,
    this.username,
    this.email,
    this.avatarUrl,
    this.avatarBase64,
  });

  User.getInit({
    this.init = true,
  });

  User.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    username = json['username']?.toString();
    email = json['email']?.toString();
    avatarUrl = json['avatarUrl']?.toString();
    avatarBase64 = json['avatarBase64']?.toString();
    init = false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    if (username != null) data['username'] = username;
    if (email != null) data['email'] = email;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (avatarBase64 != null) data['avatarBase64'] = avatarBase64;
    return data;
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    String? avatarBase64,
    bool? init,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarBase64: avatarBase64 ?? this.avatarBase64,
    )..init = init ?? this.init;
  }
}
