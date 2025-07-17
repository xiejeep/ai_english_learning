import '../../../../shared/models/message_model.dart';
import '../entities/conversation.dart';
import '../../data/datasources/chat_remote_datasource.dart';

abstract class ChatRepository {
  // 提供对 remoteDataSource 的访问
  ChatRemoteDataSource get remoteDataSource;



  
  // 发送消息并返回包含会话ID的流式响应（带type参数）
  Stream<Map<String, dynamic>> sendMessageStreamWithConversationIdAndType({
    required String message,
    required String conversationId,
    String? type,
    String? appId,
  });
  
  // 停止AI回复
  Future<void> stopGeneration();
  
  // 获取会话的所有消息
  Future<List<MessageModel>> getMessages(String conversationId, {String? appId});
  
  // 获取会话消息（带分页参数）
  Future<(List<MessageModel>, bool)> getMessagesWithPagination(
    String conversationId, {
    int? limit,
    String? firstId,
    String? appId,
  });
  
  // 保存消息到本地
  Future<void> saveMessage(MessageModel message);
  
  // 删除消息
  Future<void> deleteMessage(String messageId);
  
  // 创建新会话
  Future<Conversation> createConversation(String title);
  
  // 获取会话列表
  Future<List<Conversation>> getConversations({String? appId});
  
  // 获取最新会话
  Future<Conversation?> getLatestConversation({String? appId});
  
  // 获取最新消息历史（直接调用latest/messages接口）
  Future<List<MessageModel>> getLatestMessages({String? appId});
  
  // 删除会话
  Future<void> deleteConversation(String conversationId, {String? appId});
  
  // 更新会话标题
  Future<void> updateConversationTitle(String conversationId, String title, {String? appId});
  
  // 更新会话名称
  Future<void> updateConversationName(String conversationId, String name, {String? appId});
  
  // 获取TTS音频文件路径
  Future<String> getTTSAudio(String text, {String? appId});
  
  // 获取token使用历史
  // Future<List<TokenUsageModel>> getTokenUsageHistory(); // 已废弃，删除
}