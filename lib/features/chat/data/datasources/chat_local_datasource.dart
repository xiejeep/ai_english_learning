import 'dart:convert';
import '../../../../core/storage/storage_service.dart';
import '../../../../shared/models/message_model.dart';
import '../models/conversation_model.dart';

class ChatLocalDataSource {
  static const String _messagesKey = 'chat_messages';
  static const String _conversationsKey = 'conversations';
  
  // 保存消息到本地
  Future<void> saveMessage(MessageModel message) async {
    try {
      final messages = await getMessages(message.conversationId ?? '');
      messages.add(message);
      
      final messagesJson = messages.map((m) => m.toJson()).toList();
      await StorageService.save(
        '${_messagesKey}_${message.conversationId}', 
        jsonEncode(messagesJson)
      );
    } catch (e) {
      print('保存消息失败: $e');
      throw Exception('保存消息失败: $e');
    }
  }
  
  // 获取会话的所有消息
  Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final messagesStr = StorageService.get<String>('${_messagesKey}_$conversationId');
      if (messagesStr == null) return [];
      
      final messagesList = jsonDecode(messagesStr) as List;
      return messagesList
          .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('获取消息失败: $e');
      return [];
    }
  }
  
  // 删除消息
  Future<void> deleteMessage(String messageId, String conversationId) async {
    try {
      final messages = await getMessages(conversationId);
      messages.removeWhere((m) => m.id == messageId);
      
      final messagesJson = messages.map((m) => m.toJson()).toList();
      await StorageService.save(
        '${_messagesKey}_$conversationId', 
        jsonEncode(messagesJson)
      );
    } catch (e) {
      print('删除消息失败: $e');
      throw Exception('删除消息失败: $e');
    }
  }
  
  // 保存会话
  Future<void> saveConversation(ConversationModel conversation) async {
    try {
      final conversations = await getConversations();
      
      // 检查是否已存在，如果存在则更新，否则添加
      final existingIndex = conversations.indexWhere((c) => c.id == conversation.id);
      if (existingIndex != -1) {
        conversations[existingIndex] = conversation;
      } else {
        conversations.add(conversation);
      }
      
      // 按更新时间排序（最新的在前）
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      final conversationsJson = conversations.map((c) => c.toJson()).toList();
      await StorageService.save(_conversationsKey, jsonEncode(conversationsJson));
    } catch (e) {
      print('保存会话失败: $e');
      throw Exception('保存会话失败: $e');
    }
  }
  
  // 获取所有会话
  Future<List<ConversationModel>> getConversations() async {
    try {
      final conversationsStr = StorageService.get<String>(_conversationsKey);
      if (conversationsStr == null) return [];
      
      final conversationsList = jsonDecode(conversationsStr) as List;
      final conversations = conversationsList
          .map((json) => ConversationModel.fromJson(json as Map<String, dynamic>))
          .toList();
      
      // 按更新时间降序排序，确保最新的会话排在前面
      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      return conversations;
    } catch (e) {
      print('获取会话列表失败: $e');
      return [];
    }
  }
  
  // 删除会话
  Future<void> deleteConversation(String conversationId) async {
    try {
      // 删除会话记录
      final conversations = await getConversations();
      conversations.removeWhere((c) => c.id == conversationId);
      
      final conversationsJson = conversations.map((c) => c.toJson()).toList();
      await StorageService.save(_conversationsKey, jsonEncode(conversationsJson));
      
      // 删除会话的所有消息
      await StorageService.remove('${_messagesKey}_$conversationId');
    } catch (e) {
      print('删除会话失败: $e');
      throw Exception('删除会话失败: $e');
    }
  }
  
  // 更新会话标题
  Future<void> updateConversationTitle(String conversationId, String title) async {
    try {
      final conversations = await getConversations();
      final index = conversations.indexWhere((c) => c.id == conversationId);
      
      if (index != -1) {
        final updatedConversation = ConversationModel(
          id: conversations[index].id,
          title: title,
          name: conversations[index].name,
          introduction: conversations[index].introduction,
          createdAt: conversations[index].createdAt,
          updatedAt: DateTime.now(),
          messageCount: conversations[index].messageCount,
          lastMessage: conversations[index].lastMessage,
        );
        
        await saveConversation(updatedConversation);
      }
    } catch (e) {
      print('更新会话标题失败: $e');
      throw Exception('更新会话标题失败: $e');
    }
  }

  // 更新会话名称
  Future<void> updateConversationName(String conversationId, String name) async {
    try {
      final conversations = await getConversations();
      final index = conversations.indexWhere((c) => c.id == conversationId);
      
      if (index != -1) {
        final updatedConversation = ConversationModel(
          id: conversations[index].id,
          title: conversations[index].title,
          name: name,
          introduction: conversations[index].introduction,
          createdAt: conversations[index].createdAt,
          updatedAt: DateTime.now(),
          messageCount: conversations[index].messageCount,
          lastMessage: conversations[index].lastMessage,
        );
        
        await saveConversation(updatedConversation);
      }
    } catch (e) {
      print('更新会话名称失败: $e');
      throw Exception('更新会话名称失败: $e');
    }
  }
  
  // 更新会话的最后一条消息和消息数量
  Future<void> updateConversationMeta(String conversationId, String lastMessage) async {
    try {
      final conversations = await getConversations();
      final index = conversations.indexWhere((c) => c.id == conversationId);
      
      if (index != -1) {
        final messages = await getMessages(conversationId);
        final updatedConversation = ConversationModel(
          id: conversations[index].id,
          title: conversations[index].title,
          name: conversations[index].name,
          introduction: conversations[index].introduction,
          createdAt: conversations[index].createdAt,
          updatedAt: DateTime.now(),
          messageCount: messages.length,
          lastMessage: lastMessage,
        );
        
        await saveConversation(updatedConversation);
      }
    } catch (e) {
      print('更新会话元信息失败: $e');
      throw Exception('更新会话元信息失败: $e');
    }
  }
} 