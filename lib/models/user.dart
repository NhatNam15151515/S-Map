class User {
  String? id;
  String? username;
  String? email;
  String? avatarUrl;
  bool init = false;

  User({
    this.id,
    this.username,
    this.email,
    this.avatarUrl,
  });

  User.getInit({
    this.init = true,
  });

  User.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toString();
    username = json['username'];
    email = json['email'];
    avatarUrl = json['avatarUrl'];
    init = false;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    if (username != null) data['username'] = username;
    if (email != null) data['email'] = email;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    return data;
  }
}
