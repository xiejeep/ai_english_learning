import '../../domain/entities/conversation.dart';

class ConversationModel extends Conversation {
  const ConversationModel({
    required super.id,
    required super.title,
    super.name,
    super.introduction,
    required super.createdAt,
    required super.updatedAt,
    required super.messageCount,
    super.lastMessage,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      title: json['title'] as String,
      name: json['name'] as String?,
      introduction: json['introduction'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      messageCount: json['message_count'] as int,
      lastMessage: json['last_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'name': name,
      'introduction': introduction,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'message_count': messageCount,
      'last_message': lastMessage,
    };
  }

  factory ConversationModel.fromEntity(Conversation conversation) {
    return ConversationModel(
      id: conversation.id,
      title: conversation.title,
      name: conversation.name,
      introduction: conversation.introduction,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
      messageCount: conversation.messageCount,
      lastMessage: conversation.lastMessage,
    );
  }
} 