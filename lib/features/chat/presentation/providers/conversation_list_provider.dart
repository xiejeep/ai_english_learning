import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/datasources/chat_remote_datasource.dart';

// 会话列表状态
class ConversationListState {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? error;

  const ConversationListState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationListState copyWith({
    List<Conversation>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  ConversationListState setLoading() {
    return copyWith(isLoading: true, error: null);
  }

  ConversationListState setError(String error) {
    return copyWith(isLoading: false, error: error);
  }

  ConversationListState setSuccess(List<Conversation> conversations) {
    return copyWith(conversations: conversations, isLoading: false, error: null);
  }
}

// 会话列表状态管理器
class ConversationListNotifier extends StateNotifier<ConversationListState> {
  final ChatRepository _repository;

  ConversationListNotifier(this._repository) : super(const ConversationListState());

  // 加载会话列表
  Future<void> loadConversations({String? appId}) async {
    try {
      print('🔄 [会话列表] 开始加载会话列表... appId=$appId');
      state = state.setLoading();
      
      final conversations = await _repository.getConversations(appId: appId);
      
      print('✅ [会话列表] 成功加载会话列表，共 ${conversations.length} 个会话');
      for (int i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        print('📋 [会话列表] 会话 ${i + 1}: ID=${conv.id}, 标题=${conv.title}, 名称=${conv.name}');
      }
      
      state = state.setSuccess(conversations);
    } catch (e) {
      print('❌ [会话列表] 加载会话列表失败: $e');
      
      // 根据错误类型提供友好的用户提示
      String userFriendlyError = _getUserFriendlyError(e);
      state = state.setError(userFriendlyError);
    }
  }

  // 将技术错误信息转换为用户友好的提示
  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('connection') || errorString.contains('timeout')) {
      return '网络连接失败，请检查网络设置后重试';
    } else if (errorString.contains('server') || errorString.contains('500')) {
      return '服务器暂时无法响应，请稍后重试';
    } else if (errorString.contains('unauthorized') || errorString.contains('401')) {
      return '登录已过期，请重新登录';
    } else if (errorString.contains('forbidden') || errorString.contains('403')) {
      return '访问权限不足，请联系管理员';
    } else {
      return '连接服务器失败，请检查网络连接';
    }
  }

  // 删除会话
  Future<void> deleteConversation(String conversationId, {String? appId}) async {
    try {
      await _repository.deleteConversation(conversationId, appId: appId);
      
      // 从列表中移除已删除的会话
      final updatedConversations = state.conversations
          .where((conv) => conv.id != conversationId)
          .toList();
      
      state = state.setSuccess(updatedConversations);
      
      print('✅ [会话列表] 会话删除成功: $conversationId');
    } catch (e) {
      print('❌ [会话列表] 删除会话失败: $e');
      
      String userFriendlyError = _getUserFriendlyError(e);
      state = state.setError(userFriendlyError);
    }
  }

  // 更新会话标题
  Future<void> updateConversationTitle(String conversationId, String title, {String? appId}) async {
    try {
      await _repository.updateConversationTitle(conversationId, title, appId: appId);
      
      // 更新本地列表中的会话标题
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == conversationId) {
          return conv.copyWith(title: title);
        }
        return conv;
      }).toList();
      
      state = state.setSuccess(updatedConversations);
      
      print('✅ [会话列表] 会话标题更新成功: $conversationId -> $title');
    } catch (e) {
      print('❌ [会话列表] 更新会话标题失败: $e');
      
      String userFriendlyError = _getUserFriendlyError(e);
      state = state.setError(userFriendlyError);
    }
  }

  // 更新会话名称
  Future<void> updateConversationName(String conversationId, String name, {String? appId}) async {
    try {
      await _repository.updateConversationName(conversationId, name, appId: appId);
      
      // 更新本地列表中的会话名称
      final updatedConversations = state.conversations.map((conv) {
        if (conv.id == conversationId) {
          return conv.copyWith(name: name);
        }
        return conv;
      }).toList();
      
      state = state.setSuccess(updatedConversations);
      
      print('✅ [会话列表] 会话名称更新成功: $conversationId -> $name');
    } catch (e) {
      print('❌ [会话列表] 更新会话名称失败: $e');
      
      String userFriendlyError = _getUserFriendlyError(e);
      state = state.setError(userFriendlyError);
    }
  }

  // 刷新会话列表（强制重新加载）
  Future<void> refreshConversations({String? appId}) async {
    await loadConversations(appId: appId);
  }

  // 清除错误状态
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

// Provider 依赖定义
final conversationListRepositoryProvider = Provider<ChatRepository>((ref) {
  final remoteDataSource = ChatRemoteDataSource();
  return ChatRepositoryImpl(remoteDataSource);
});

// Provider 定义
final conversationListProvider = StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  final repository = ref.read(conversationListRepositoryProvider);
  return ConversationListNotifier(repository);
});