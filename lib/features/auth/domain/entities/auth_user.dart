class AuthUser {
  final String id;
  final String username;
  final String email;
  final String? phone;
  final String? avatar;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    this.avatar,
    required this.createdAt,
    this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AuthUser &&
        other.id == id &&
        other.username == username &&
        other.email == email &&
        other.phone == phone &&
        other.avatar == avatar &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        username.hashCode ^
        email.hashCode ^
        phone.hashCode ^
        avatar.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }

  @override
  String toString() {
    return 'AuthUser(id: $id, username: $username, email: $email, phone: $phone, avatar: $avatar, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
} 