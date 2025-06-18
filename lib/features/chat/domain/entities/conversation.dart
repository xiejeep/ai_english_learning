class Conversation {
  final String id;
  final String title; // 保留title用于向后兼容
  final String? name; // 会话名称
  final String? introduction; // 会话开场白
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;
  final String? lastMessage;

  const Conversation({
    required this.id,
    required this.title,
    this.name,
    this.introduction,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.lastMessage,
  });

  // 获取显示名称，优先使用name，否则使用title
  String get displayName => name?.isNotEmpty == true ? name! : title;

  Conversation copyWith({
    String? id,
    String? title,
    String? name,
    String? introduction,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
    String? lastMessage,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      introduction: introduction ?? this.introduction,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      lastMessage: lastMessage ?? this.lastMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is Conversation &&
        other.id == id &&
        other.title == title &&
        other.name == name &&
        other.introduction == introduction &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.messageCount == messageCount &&
        other.lastMessage == lastMessage;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        name.hashCode ^
        introduction.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode ^
        messageCount.hashCode ^
        lastMessage.hashCode;
  }
} 