import '../../../../shared/models/message_model.dart';
import '../entities/conversation.dart';

abstract class ChatRepository {
  // 发送消息并获取AI回复（流式）
  Stream<String> sendMessageStream({
    required String message,
    required String conversationId,
  });

  // 发送消息并返回包含会话ID的流式响应
  Stream<Map<String, dynamic>> sendMessageStreamWithConversationId({
    required String message,
    required String conversationId,
  });
  
  // 发送消息并获取完整AI回复
  Future<MessageModel> sendMessage({
    required String message,
    required String conversationId,
  });
  
  // 停止AI回复
  Future<void> stopGeneration();
  
  // 获取会话的所有消息
  Future<List<MessageModel>> getMessages(String conversationId);
  
  // 获取会话消息（带分页参数）
  Future<(List<MessageModel>, bool)> getMessagesWithPagination(
    String conversationId, {
    int? limit,
    String? firstId,
  });
  
  // 保存消息到本地
  Future<void> saveMessage(MessageModel message);
  
  // 删除消息
  Future<void> deleteMessage(String messageId);
  
  // 创建新会话
  Future<Conversation> createConversation(String title);
  
  // 获取会话列表
  Future<List<Conversation>> getConversations();
  
  // 获取最新会话
  Future<Conversation?> getLatestConversation();
  
  // 删除会话
  Future<void> deleteConversation(String conversationId);
  
  // 更新会话标题
  Future<void> updateConversationTitle(String conversationId, String title);
  
  // 更新会话名称
  Future<void> updateConversationName(String conversationId, String name);
  
  // 获取TTS音频文件路径
  Future<String> getTTSAudio(String text);
}