import 'dart:math';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../shared/models/message_model.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/chat_local_datasource.dart';
import '../models/conversation_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;
  final ChatLocalDataSource _localDataSource;
  
  ChatRepositoryImpl(this._remoteDataSource, this._localDataSource);
  
  @override
  Stream<String> sendMessageStream({
    required String message,
    required String conversationId,
  }) {
    return _remoteDataSource.sendMessageStream(
      message: message,
      conversationId: conversationId,
      userId: 'default_user', // 后续应该从认证状态获取真实用户ID
    );
  }

  @override
  Stream<Map<String, dynamic>> sendMessageStreamWithConversationId({
    required String message,
    required String conversationId,
  }) {
    return _remoteDataSource.sendMessageStreamWithConversationId(
      message: message,
      conversationId: conversationId,
      userId: 'default_user', // 后续应该从认证状态获取真实用户ID
    );
  }
  
  @override
  Future<MessageModel> sendMessage({
    required String message,
    required String conversationId,
  }) async {
    final response = await _remoteDataSource.sendMessage(
      message: message,
      conversationId: conversationId,
      userId: 'default_user',
    );
    
    // 解析AI回复
    final aiMessage = MessageModel(
      id: _generateMessageId(),
      content: response['answer'] as String? ?? '',
      type: MessageType.ai,
      status: MessageStatus.received,
      timestamp: DateTime.now(),
      conversationId: conversationId,
      correction: response['correction'] as String?,
      translation: response['translation'] as String?,
      suggestion: response['suggestion'] as String?,
    );
    
    // 保存到本地
    await _localDataSource.saveMessage(aiMessage);
    
    return aiMessage;
  }
  
  @override
  Future<void> stopGeneration() async {
    _remoteDataSource.stopGeneration();
  }
  
  @override
  Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      // 首先尝试从远程API获取会话消息
      final messagesData = await _remoteDataSource.getConversationMessages(conversationId);
      
      // 将API响应转换为MessageModel列表
      final messages = messagesData.map((data) {
        // 处理时间戳转换
        final createdAtTimestamp = data['created_at'];
        DateTime createdAt = DateTime.now();
        if (createdAtTimestamp is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtTimestamp * 1000);
        } else if (createdAtTimestamp is String) {
          createdAt = DateTime.tryParse(createdAtTimestamp) ?? DateTime.now();
        }
        
        // 根据role字段确定消息类型
        final role = data['role'] as String? ?? 'user';
        final messageType = role == 'assistant' ? MessageType.ai : MessageType.user;
        
        return MessageModel(
          id: data['id'] as String,
          content: data['content'] as String? ?? '',
          type: messageType,
          status: MessageStatus.received,
          timestamp: createdAt,
          conversationId: conversationId,
        );
      }).toList();
      
      // 按时间戳排序，确保消息顺序正确
      messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      // 将远程获取的消息保存到本地存储
      for (final message in messages) {
        await _localDataSource.saveMessage(message);
      }
      
      print('🔄 从远程API获取会话 $conversationId 的 ${messages.length} 条消息');
      return messages;
    } catch (e) {
      print('从远程API获取会话消息失败，尝试使用本地数据: $e');
      // 如果远程API失败，回退到本地存储
      return await _localDataSource.getMessages(conversationId);
    }
  }
  
  @override
  Future<void> saveMessage(MessageModel message) async {
    await _localDataSource.saveMessage(message);
    
    // 更新会话元信息
    if (message.conversationId != null) {
      await _localDataSource.updateConversationMeta(
        message.conversationId!,
        message.content.length > 50 
            ? '${message.content.substring(0, 50)}...'
            : message.content,
      );
    }
  }
  
  @override
  Future<void> deleteMessage(String messageId) async {
    // 需要知道conversationId才能删除，这里需要改进
    // 暂时通过获取所有会话来查找
    final conversations = await getConversations();
    for (final conversation in conversations) {
      final messages = await getMessages(conversation.id);
      final messageExists = messages.any((m) => m.id == messageId);
      if (messageExists) {
        await _localDataSource.deleteMessage(messageId, conversation.id);
        break;
      }
    }
  }
  
  @override
  Future<Conversation> createConversation(String title) async {
    final conversation = ConversationModel(
      id: _generateConversationId(),
      title: title,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messageCount: 0,
    );
    
    await _localDataSource.saveConversation(conversation);
    
    return conversation;
  }
  
  @override
  Future<List<Conversation>> getConversations() async {
    try {
      // 从远程API获取会话列表
      final conversationsData = await _remoteDataSource.getConversations();
      
      // 将API响应转换为Conversation实体
      final conversations = conversationsData.map((data) {
        // 处理时间戳转换（API返回的是秒级时间戳）
        final createdAtTimestamp = data['created_at'];
        DateTime createdAt = DateTime.now();
        if (createdAtTimestamp is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtTimestamp * 1000);
        } else if (createdAtTimestamp is String) {
          createdAt = DateTime.tryParse(createdAtTimestamp) ?? DateTime.now();
        }
        
        final updatedAtTimestamp = data['updated_at'];
        DateTime updatedAt = DateTime.now();
        if (updatedAtTimestamp is int) {
          updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtTimestamp * 1000);
        } else if (updatedAtTimestamp is String) {
          updatedAt = DateTime.tryParse(updatedAtTimestamp) ?? DateTime.now();
        }
        
        return ConversationModel(
          id: data['id'] as String,
          title: data['name'] as String? ?? '新对话',
          name: data['name'] as String?,
          introduction: data['introduction'] as String?, // API响应中包含introduction字段
          createdAt: createdAt,
          updatedAt: updatedAt,
          messageCount: 0, // API响应中可能没有消息数量
          lastMessage: null, // API响应中可能没有最后一条消息
        );
      }).toList();
      
      return conversations.cast<Conversation>();
    } catch (e) {
      print('从远程API获取会话列表失败，尝试使用本地数据: $e');
      // 如果远程API失败，回退到本地存储
      final conversations = await _localDataSource.getConversations();
      return conversations.cast<Conversation>();
    }
  }
  
  @override
  Future<void> deleteConversation(String conversationId) async {
    try {
      // 先尝试从远程API删除
      final success = await _remoteDataSource.deleteConversation(conversationId);
      if (success) {
        // 远程删除成功后，也删除本地数据
        await _localDataSource.deleteConversation(conversationId);
      } else {
        throw Exception('远程删除会话失败');
      }
    } catch (e) {
      print('删除会话时出错: $e');
      // 如果远程删除失败，仍然删除本地数据
      await _localDataSource.deleteConversation(conversationId);
      throw e;
    }
  }
  
  @override
  Future<void> updateConversationTitle(String conversationId, String title) async {
    try {
      // 先尝试从远程API更新
      final success = await _remoteDataSource.renameConversation(conversationId, title);
      if (success) {
        // 远程更新成功后，也更新本地数据
        await _localDataSource.updateConversationTitle(conversationId, title);
      } else {
        throw Exception('远程更新会话标题失败');
      }
    } catch (e) {
      print('更新会话标题时出错: $e');
      // 如果远程更新失败，仍然更新本地数据
      await _localDataSource.updateConversationTitle(conversationId, title);
      throw e;
    }
  }

  @override
  Future<void> updateConversationName(String conversationId, String name) async {
    try {
      // 先尝试从远程API更新
      final success = await _remoteDataSource.renameConversation(conversationId, name);
      if (success) {
        // 远程更新成功后，也更新本地数据
        await _localDataSource.updateConversationName(conversationId, name);
      } else {
        throw Exception('远程更新会话名称失败');
      }
    } catch (e) {
      print('更新会话名称时出错: $e');
      // 如果远程更新失败，仍然更新本地数据
      await _localDataSource.updateConversationName(conversationId, name);
      throw e;
    }
  }
  
  @override
  Future<String> getTTSAudio(String text) async {
    return await _remoteDataSource.getTTSAudio(text);
  }
  
  @override
  Stream<String> getTTSAudioStream({
    required String text,
    required String messageId,
    String? voice,
  }) {
    return _remoteDataSource.getTTSAudioStream(
      text: text,
      messageId: messageId,
      voice: voice ?? 'default',
    );
  }
  
  // 生成消息ID
  String _generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'msg_${timestamp}_$random';
  }
  
  // 生成会话ID
  String _generateConversationId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'conv_${timestamp}_$random';
  }
} 