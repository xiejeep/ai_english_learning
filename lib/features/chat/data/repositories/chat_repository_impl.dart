import 'dart:async';
import 'dart:math';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../models/conversation_model.dart';
import '../../../../shared/models/message_model.dart';
import '../../../../core/storage/storage_service.dart';
class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;

  ChatRepositoryImpl(this._remoteDataSource);
  
  // 提供对 remoteDataSource 的访问
  ChatRemoteDataSource get remoteDataSource => _remoteDataSource;

  @override
  Stream<String> sendMessageStream({
    required String message,
    required String conversationId,
    String? appId,
  }) {
    return _remoteDataSource.sendMessageStream(
      message: message,
      conversationId: conversationId,
      userId: _getCurrentUserId(),
      appId: appId,
    );
  }


  
  @override
  Stream<Map<String, dynamic>> sendMessageStreamWithConversationIdAndType({
    required String message,
    required String conversationId,
    String? type,
    String? appId,
  }) {
    return _remoteDataSource.sendMessageStreamWithConversationIdAndType(
      message: message,
      conversationId: conversationId,
      type: type,
      appId: appId,
    );
  }



  @override
  Future<void> stopGeneration() async {
    _remoteDataSource.stopGeneration();
  }

  @override
  Future<String> getTTSAudio(String text, {String? appId}) async {
    return await _remoteDataSource.getTTSAudio(text, appId: appId);
  }

  @override
  Future<List<MessageModel>> getMessages(String conversationId, {String? appId}) async {
    // 直接从远程API获取会话消息
    final messagesData = await _remoteDataSource.getConversationMessages(conversationId, appId: appId);
    
    // 将API响应转换为MessageModel
    final messages = messagesData.map((data) {
      final role = data['role'] as String;
      final messageType = role == 'assistant' ? MessageType.ai : MessageType.user;
      
      return MessageModel(
        id: data['id'] as String,
        content: data['content'] as String,
        type: messageType,
        status: MessageStatus.received,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (data['created_at'] as int) * 1000,
        ),
        conversationId: data['conversation_id'] as String? ?? conversationId,
      );
    }).toList();

    // 按时间戳排序（从旧到新）
    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    print('🔄 从远程API获取会话 $conversationId 的 ${messages.length} 条消息');
    return messages;
  }
  
  @override
  Future<(List<MessageModel>, bool)> getMessagesWithPagination(
    String conversationId, {
    int? limit,
    String? firstId,
    String? appId,
  }) async {
    print('🔍 [DEBUG] Repository收到分页请求: conversationId=$conversationId, limit=$limit, firstId=$firstId, appId=$appId');
    
    // 从远程数据源获取消息
    final result = await _remoteDataSource.getConversationMessagesWithPagination(
      conversationId,
      limit: limit,
      firstId: firstId,
      appId: appId,
    );
    
    final messagesData = result['messages'] as List<Map<String, dynamic>>;
    final hasMore = result['has_more'] as bool;
    
    print('📊 Repository收到分页结果: 消息数=${messagesData.length}, has_more=$hasMore');
    
    // 将API响应转换为MessageModel
    final messages = messagesData.map((data) {
      // 处理时间戳转换（API返回的是秒级时间戳）
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

    return (messages, hasMore);
  }
  
  @override
  Future<void> saveMessage(MessageModel message) async {
    // 移除本地存储，这个方法现在不做任何操作
    // 消息保存完全依赖远程API的持久化
    print('💾 消息已通过API保存: ${message.id}');
  }
  
  @override
  Future<void> deleteMessage(String messageId) async {
    // 这里可以实现远程删除消息的API调用
    // 暂时只记录日志
    print('🗑️ 删除消息: $messageId');
  }

  @override
  Future<List<Conversation>> getConversations({String? appId}) async {
    // 直接从远程API获取会话列表
    final conversationsData = await _remoteDataSource.getConversations(appId: appId);
    
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

    // 按更新时间降序排序，确保最新的会话排在前面
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return conversations.cast<Conversation>();
  }
  
  @override
  Future<void> deleteConversation(String conversationId, {String? appId}) async {
    await _remoteDataSource.deleteConversation(conversationId, appId: appId);
  }
  
  @override
  Future<void> updateConversationTitle(String conversationId, String title, {String? appId}) async {
    await _remoteDataSource.renameConversation(conversationId, title, appId: appId);
  }

  @override
  Future<void> updateConversationName(String conversationId, String name, {String? appId}) async {
    await _remoteDataSource.renameConversation(conversationId, name, appId: appId);
  }

  @override
  Future<Conversation?> getLatestConversation({String? appId}) async {
    print('🚀 开始加载最新会话... appId=$appId');
    
    // 直接从远程API获取最新会话
    final latestConversationData = await _remoteDataSource.getLatestConversation(appId: appId);
    
    if (latestConversationData != null) {
      // 处理时间戳转换（API返回的是秒级时间戳）
      final createdAtTimestamp = latestConversationData['created_at'];
      DateTime createdAt = DateTime.now();
      if (createdAtTimestamp is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtTimestamp * 1000);
      } else if (createdAtTimestamp is String) {
        createdAt = DateTime.tryParse(createdAtTimestamp) ?? DateTime.now();
      }
      
      final updatedAtTimestamp = latestConversationData['updated_at'];
      DateTime updatedAt = DateTime.now();
      if (updatedAtTimestamp is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtTimestamp * 1000);
      } else if (updatedAtTimestamp is String) {
        updatedAt = DateTime.tryParse(updatedAtTimestamp) ?? DateTime.now();
      }
      
      final latestConversation = ConversationModel(
        id: latestConversationData['id'] as String,
        title: latestConversationData['name'] as String? ?? '新对话',
        name: latestConversationData['name'] as String?,
        introduction: latestConversationData['introduction'] as String?, // API响应中包含introduction字段
        createdAt: createdAt,
        updatedAt: updatedAt,
        messageCount: 0, // API响应中可能没有消息数量
        lastMessage: null, // API响应中可能没有最后一条消息
      );
      
      return latestConversation;
    }
    
    return null;
  }

  @override
  Future<Conversation> createConversation(String title) async {
    // 创建一个临时会话对象，ID由服务器生成
    final conversation = ConversationModel(
      id: "", // 空ID，等待服务器分配
      title: title,
      name: title,
      introduction: '欢迎来到AI英语学习助手！我可以帮助你练习英语对话、纠正语法错误、提供翻译建议。请随时开始我们的英语学习之旅吧！',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messageCount: 0,
    );
    
    return conversation;
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

  String _getCurrentUserId() {
    final userMap = StorageService.getUser();
    if (userMap != null && userMap['id'] != null && userMap['id'].toString().isNotEmpty) {
      return userMap['id'].toString();
    }
    return 'default_user';
  }
}