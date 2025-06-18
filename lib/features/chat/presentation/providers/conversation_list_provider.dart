import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/chat_local_datasource.dart';

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
  Future<void> loadConversations() async {
    try {
      print('🔄 [会话列表] 开始加载会话列表...');
      state = state.setLoading();
      
      final conversations = await _repository.getConversations();
      
      print('✅ [会话列表] 成功加载会话列表，共 ${conversations.length} 个会话');
      for (int i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        print('📋 [会话列表] 会话 ${i + 1}: ID=${conv.id}, 标题=${conv.title}, 名称=${conv.name}');
      }
      
      state = state.setSuccess(conversations);
    } catch (e) {
      print('❌ [会话列表] 加载会话列表失败: $e');
      state = state.setError('加载会话列表失败: $e');
    }
  }

  // 删除会话
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _repository.deleteConversation(conversationId);
      
      // 从列表中移除已删除的会话
      final updatedConversations = state.conversations
          .where((conv) => conv.id != conversationId)
          .toList();
      
      state = state.setSuccess(updatedConversations);
      
      print('✅ [会话列表] 会话删除成功: $conversationId');
    } catch (e) {
      print('❌ [会话列表] 删除会话失败: $e');
      state = state.setError('删除会话失败: $e');
    }
  }

  // 更新会话标题
  Future<void> updateConversationTitle(String conversationId, String title) async {
    try {
      await _repository.updateConversationTitle(conversationId, title);
      
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
      state = state.setError('更新会话标题失败: $e');
    }
  }

  // 更新会话名称
  Future<void> updateConversationName(String conversationId, String name) async {
    try {
      await _repository.updateConversationName(conversationId, name);
      
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
      state = state.setError('更新会话名称失败: $e');
    }
  }

  // 刷新会话列表（强制重新加载）
  Future<void> refreshConversations() async {
    await loadConversations();
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
  final localDataSource = ChatLocalDataSource();
  return ChatRepositoryImpl(remoteDataSource, localDataSource);
});

// Provider 定义
final conversationListProvider = StateNotifierProvider<ConversationListNotifier, ConversationListState>((ref) {
  final repository = ref.read(conversationListRepositoryProvider);
  return ConversationListNotifier(repository);
}); 