import 'package:flutter/material.dart';

enum MessageType { user, ai, system }

enum MessageStatus { sending, sent, failed, received }

class MessageModel {
  final String id;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final String? conversationId;

  // AI回复的额外信息
  final String? correction; // 语法纠错
  final String? translation; // 翻译
  final String? suggestion; // 学习建议
  final String? audioUrl; // 语音文件URL
  // 新增：富文本内容（仅本地使用，不参与json序列化）
  final List<InlineSpan>? richContent;
  // 新增：错误信息（用于显示发送失败的详细原因）
  final String? errorMessage;

  const MessageModel({
    required this.id,
    required this.content,
    required this.type,
    required this.status,
    required this.timestamp,
    this.conversationId,
    this.correction,
    this.translation,
    this.suggestion,
    this.audioUrl,
    this.richContent,
    this.errorMessage,
  });

  // 从JSON创建对象
  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      content: json['content'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.user,
      ),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      conversationId: json['conversation_id'] as String?,
      correction: json['correction'] as String?,
      translation: json['translation'] as String?,
      suggestion: json['suggestion'] as String?,
      audioUrl: json['audio_url'] as String?,
      richContent: null, // 富文本内容仅本地生成，不从json恢复
      errorMessage: json['error_message'] as String?,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'conversation_id': conversationId,
      'correction': correction,
      'translation': translation,
      'suggestion': suggestion,
      'audio_url': audioUrl,
      'error_message': errorMessage,
    };
  }

  // 复制对象并修改部分字段
  MessageModel copyWith({
    String? id,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    String? conversationId,
    String? correction,
    String? translation,
    String? suggestion,
    String? audioUrl,
    List<InlineSpan>? richContent,
    String? errorMessage,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      conversationId: conversationId ?? this.conversationId,
      correction: correction ?? this.correction,
      translation: translation ?? this.translation,
      suggestion: suggestion ?? this.suggestion,
      audioUrl: audioUrl ?? this.audioUrl,
      richContent: richContent ?? this.richContent,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // 判断是否为用户消息
  bool get isUser => type == MessageType.user;

  // 判断是否为AI消息
  bool get isAI => type == MessageType.ai;

  // 判断是否有语法纠错
  bool get hasCorrection => correction != null && correction!.isNotEmpty;

  // 判断是否有翻译
  bool get hasTranslation => translation != null && translation!.isNotEmpty;

  // 判断是否有建议
  bool get hasSuggestion => suggestion != null && suggestion!.isNotEmpty;

  // 判断是否有音频
  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  // 判断是否有错误信息
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MessageModel &&
        other.id == id &&
        other.content == content &&
        other.type == type &&
        other.status == status &&
        other.timestamp == timestamp &&
        other.conversationId == conversationId &&
        other.correction == correction &&
        other.translation == translation &&
        other.suggestion == suggestion &&
        other.audioUrl == audioUrl &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        content.hashCode ^
        type.hashCode ^
        status.hashCode ^
        timestamp.hashCode ^
        conversationId.hashCode ^
        correction.hashCode ^
        translation.hashCode ^
        suggestion.hashCode ^
        audioUrl.hashCode ^
        errorMessage.hashCode;
  }

  @override
  String toString() {
    return 'MessageModel(id: $id, content: $content, type: $type, status: $status, timestamp: $timestamp, conversationId: $conversationId, correction: $correction, translation: $translation, suggestion: $suggestion, audioUrl: $audioUrl, errorMessage: $errorMessage)';
  }
}
