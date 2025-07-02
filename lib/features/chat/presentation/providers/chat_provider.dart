import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/datasources/chat_local_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../shared/models/message_model.dart';
import '../../domain/entities/conversation.dart';
import '../../data/models/conversation_model.dart';
import 'chat_state.dart';
import '../../../../core/storage/storage_service.dart';

// 聊天相关的Provider
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource();
});

final chatLocalDataSourceProvider = Provider<ChatLocalDataSource>((ref) {
  return ChatLocalDataSource();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remoteDataSource = ref.read(chatRemoteDataSourceProvider);
  final localDataSource = ref.read(chatLocalDataSourceProvider);
  return ChatRepositoryImpl(remoteDataSource, localDataSource);
});

// 聊天状态管理器
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  ChatNotifier(this._repository) : super(const ChatState()) {
    _initializeTTSSettings();
  }

  // 初始化TTS设置
  void _initializeTTSSettings() {
    final autoPlay = StorageService.getTTSAutoPlay();
    state = state.copyWith(autoPlayTTS: autoPlay);
  }



  // 创建新会话（不预先生成ID，等待Dify返回）
  Future<void> createNewConversation() async {
    try {
      // 创建一个临时会话，不生成本地ID
      final tempConversation = Conversation(
        id: "", // 空ID，等待Dify分配
        title: '新对话',
        name: '新的英语学习对话',
        introduction: '欢迎来到AI英语学习助手！我可以帮助你练习英语对话、纠正语法错误、提供翻译建议。请随时开始我们的英语学习之旅吧！',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messageCount: 0,
      );
      
      state = state.copyWith(
        currentConversation: tempConversation,
        messages: [],
        status: ChatStatus.success,
      );
    } catch (e) {
      state = state.setError('创建会话失败: $e');
    }
  }



  // 切换到指定会话（分页加载）
  Future<void> switchToConversation(Conversation conversation) async {
    try {
      print('🔄 切换到会话: ${conversation.displayName} (ID: ${conversation.id})');
      state = state.setLoading();
      
      // 加载最新一组对话
      final messages = await _repository.getMessagesWithPagination(
        conversation.id,
        limit: state.pageSize,
        firstId: null, // 不指定firstId，获取最新消息
      );
      
      print('✅ 成功加载会话最新消息，共 ${messages.length} 条消息');
      
      state = state.copyWith(
        currentConversation: conversation,
        messages: messages,
        status: ChatStatus.success,
        firstId: messages.isNotEmpty ? messages.last.id : null, // 设置游标为最后一条消息的ID
        hasMoreMessages: messages.length >= state.pageSize,
        hasNewerMessages: false, // 切换会话时加载的是最新消息
      );
    } catch (e) {
      print('❌ 加载会话消息失败: $e');
      state = state.setError('加载会话消息失败: $e');
    }
  }

  // 加载最新会话（PageView版本）
  Future<void> loadLatestConversation() async {
    try {
      print('🚀 开始加载最新会话...');
      state = state.setLoading();
      
      // 获取最新会话
      final latestConversation = await _repository.getLatestConversation();
      
      if (latestConversation != null) {
        print('🎯 找到最新会话: ${latestConversation.displayName}');
        
        // 加载最新一组对话（limit=1，只加载最新的一条消息）
        final messages = await _repository.getMessagesWithPagination(
          latestConversation.id,
          limit: 1, // 只加载最新的一条消息
          firstId: null, // 不指定firstId，获取最新消息
        );
        
        print('✅ 成功加载最新会话和最新消息，共 ${messages.length} 条消息');
        
        // 初始化PageView，将最新消息作为第一页
        final conversationPages = messages.isNotEmpty ? [messages] : <List<MessageModel>>[];
        
        state = state.copyWith(
          currentConversation: latestConversation,
          messages: messages,
          status: ChatStatus.success,
          firstId: messages.isNotEmpty ? messages.last.id : null, // 设置游标为最后一条消息的ID
          hasMoreMessages: messages.length >= 1, // 如果有消息，可能还有更多历史消息
          hasNewerMessages: false, // 加载的是最新消息，没有更新的消息
          conversationPages: conversationPages,
          currentPageIndex: 0, // 当前在第一页（最新页）
        );
      } else {
        print('📝 没有找到现有会话，将创建新会话');
        state = state.copyWith(
          currentConversation: null,
          messages: [],
          status: ChatStatus.success,
          firstId: null,
          hasMoreMessages: false,
          hasNewerMessages: false,
          conversationPages: <List<MessageModel>>[],
          currentPageIndex: 0,
        );
      }
    } catch (e) {
      print('❌ 加载最新会话失败: $e');
      state = state.setError('加载最新会话失败: $e');
    }
  }

  // 加载更多历史消息（PageView版本 - 添加新页面）
  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore || !state.hasMoreMessages || state.currentConversation == null) {
      return;
    }

    try {
      print('📖 开始加载更多历史消息，当前游标: ${state.firstId}');
      state = state.copyWith(isLoadingMore: true);
      
      // 提取原始消息ID（去掉_user或_assistant后缀）用于API请求
      final originalFirstId = state.firstId != null 
          ? _extractOriginalMessageId(state.firstId!) 
          : null;
      
      // 加载下一组对话（limit=1，加载一条历史消息）
      final newMessages = await _repository.getMessagesWithPagination(
        state.currentConversation!.id,
        limit: 1,
        firstId: originalFirstId, // 使用提取的原始消息ID
      );
      
      if (newMessages.isNotEmpty) {
        // 将新的对话页面添加到conversationPages数组的末尾
        final updatedPages = [...state.conversationPages, newMessages];
        
        state = state.copyWith(
          conversationPages: updatedPages,
          firstId: newMessages.isNotEmpty ? newMessages.last.id : state.firstId, // 更新游标为最后一条消息的ID
          hasMoreMessages: newMessages.length >= 1, // 如果返回了消息，可能还有更多
          isLoadingMore: false,
        );
        
        print('✅ 成功加载 ${newMessages.length} 条历史消息，添加新页面，总页数: ${updatedPages.length}');
      } else {
        // 没有更多消息了
        state = state.copyWith(
          hasMoreMessages: false,
          isLoadingMore: false,
        );
        print('📝 没有更多历史消息了');
      }
    } catch (e) {
      print('❌ 加载更多消息失败: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: '加载更多消息失败: $e',
      );
    }
  }

  // PageView页面切换处理
  void onPageChanged(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= state.conversationPages.length) {
      return;
    }
    
    // 更新当前页面索引和显示的消息
    final currentPageMessages = state.conversationPages[pageIndex];
    
    // 检查是否还有更多历史消息可以加载
    // 如果不在最后一页，说明可能还有更多历史消息
    final isLastPage = pageIndex == state.conversationPages.length - 1;
    final shouldShowMoreButton = !isLastPage || state.hasMoreMessages;
    
    state = state.copyWith(
      currentPageIndex: pageIndex,
      messages: currentPageMessages,
      hasNewerMessages: pageIndex > 0, // 如果不在第一页，说明有更新的消息
      hasMoreMessages: shouldShowMoreButton, // 根据当前页面位置更新hasMoreMessages
    );
    
    print('📄 切换到第 ${pageIndex + 1} 页，显示 ${currentPageMessages.length} 条消息，hasMoreMessages: $shouldShowMoreButton');
  }
  
  // 检查是否可以加载更多页面（用于PageView的预加载）
  bool get canLoadMorePages => state.hasMoreMessages && !state.isLoadingMore;

  // 发送消息（流式响应）
  Future<void> sendMessageStream(String content) async {
    if (content.trim().isEmpty) return;
    
    // 获取当前会话ID
    // 只有当会话ID以真实的Dify格式开头时才使用，否则传递空字符串
    String conversationId = "";
    final currentConv = state.currentConversation;
    if (currentConv != null && currentConv.id.isNotEmpty) {
      // 检查是否是有效的Dify会话ID（不是我们本地生成的格式）
      if (!currentConv.id.startsWith('conv_')) {
        conversationId = currentConv.id;
      }
      // 如果是本地生成的ID（conv_开头），则传递空字符串让Dify创建新会话
    }

    try {
      // 添加用户消息
      final userMessage = MessageModel(
        id: _generateMessageId(),
        content: content,
        type: MessageType.user,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        conversationId: conversationId,
      );

      // 更新状态：添加用户消息并设置发送状态
      final updatedMessages = [...state.messages, userMessage];
      
      // 更新PageView的第一页（最新页）
      List<List<MessageModel>> updatedPages = [...state.conversationPages];
      if (updatedPages.isNotEmpty) {
        updatedPages[0] = updatedMessages;
      } else {
        updatedPages = [updatedMessages];
      }
      
      state = state.copyWith(
        messages: updatedMessages,
        conversationPages: updatedPages,
        status: ChatStatus.sending,
      );

      // 保存用户消息
      await _repository.saveMessage(userMessage);

      // 设置AI思考中状态
      state = state.setThinking();

      // 创建临时AI消息用于显示流式响应
      final tempAiMessage = MessageModel(
        id: _generateMessageId(),
        content: '',
        type: MessageType.ai,
        status: MessageStatus.received,
        timestamp: DateTime.now(),
        conversationId: conversationId,
      );

      // 添加临时AI消息
      final messagesWithAI = [...state.messages, tempAiMessage];
      
      // 更新PageView的第一页（最新页）
      List<List<MessageModel>> updatedPagesWithAI = [...state.conversationPages];
      if (updatedPagesWithAI.isNotEmpty) {
        updatedPagesWithAI[0] = messagesWithAI;
      } else {
        updatedPagesWithAI = [messagesWithAI];
      }
      
      state = state.copyWith(
        messages: messagesWithAI,
        conversationPages: updatedPagesWithAI,
        status: ChatStatus.streaming,
        isStreaming: true,
      );

      String fullResponse = '';

      // 开始流式响应
      _streamSubscription = _repository.sendMessageStreamWithConversationId(
        message: content,
        conversationId: conversationId,
      ).listen(
        (data) {
          final chunk = data['content'] as String? ?? '';
          final newConversationId = data['conversation_id'] as String?;
          
          fullResponse += chunk;
          
          // 如果收到了新的会话ID，更新状态
          if (newConversationId != null && newConversationId.isNotEmpty) {
            // 如果当前会话ID为空或者是本地生成的，更新为Dify返回的真实ID
            final currentConv = state.currentConversation;
            if (currentConv == null || 
                currentConv.id.isEmpty || 
                currentConv.id.startsWith('conv_')) {
              
              // 创建/更新会话对象，使用Dify返回的真实ID
              final updatedConversation = (currentConv ?? Conversation(
                id: "",
                title: '新对话',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                messageCount: 0,
              )).copyWith(id: newConversationId);
              
              state = state.copyWith(currentConversation: updatedConversation);
              
                             // 异步保存真实的会话到本地存储
               _saveConversationAsync(updatedConversation);
              
              // 更新消息的会话ID
              final updatedUserMessage = userMessage.copyWith(conversationId: newConversationId);
              final updatedTempMessage = tempAiMessage.copyWith(conversationId: newConversationId);
              
              final updatedMessages = state.messages.map((msg) {
                if (msg.id == userMessage.id) return updatedUserMessage;
                if (msg.id == tempAiMessage.id) return updatedTempMessage;
                return msg;
              }).toList();
              
              // 同时更新PageView的第一页
              List<List<MessageModel>> updatedPagesForConvId = [...state.conversationPages];
              if (updatedPagesForConvId.isNotEmpty) {
                updatedPagesForConvId[0] = updatedMessages;
              }
              
              state = state.copyWith(
                messages: updatedMessages,
                conversationPages: updatedPagesForConvId,
              );
            }
          }
          
          // 更新临时消息的内容
          final updatedMessages = state.messages.map((msg) {
            if (msg.id == tempAiMessage.id) {
              return msg.copyWith(content: fullResponse);
            }
            return msg;
          }).toList();

          // 同时更新PageView的第一页
          List<List<MessageModel>> updatedPagesForStreaming = [...state.conversationPages];
          if (updatedPagesForStreaming.isNotEmpty) {
            updatedPagesForStreaming[0] = updatedMessages;
          }
          
          state = state.copyWith(
            messages: updatedMessages,
            conversationPages: updatedPagesForStreaming,
            streamingMessage: fullResponse,
          );
        },
        onDone: () async {
          // 流式响应完成，保存最终的AI消息
          final finalAiMessage = tempAiMessage.copyWith(
            content: fullResponse,
            status: MessageStatus.received,
          );

          await _repository.saveMessage(finalAiMessage);

          // 更新状态
          final updatedMessages = state.messages.map((msg) {
            if (msg.id == tempAiMessage.id) {
              return finalAiMessage;
            }
            return msg;
          }).toList();

          // 同时更新PageView的第一页
          List<List<MessageModel>> finalUpdatedPages = [...state.conversationPages];
          if (finalUpdatedPages.isNotEmpty) {
            finalUpdatedPages[0] = updatedMessages;
          }
          
          state = state.copyWith(
            messages: updatedMessages,
            conversationPages: finalUpdatedPages,
            status: ChatStatus.success,
            isStreaming: false,
            streamingMessage: '',
            firstId: null, // 重置游标
          );

          // 如果开启了自动播放，播放TTS
          if (state.autoPlayTTS && fullResponse.isNotEmpty) {
            playTTS(fullResponse);
          }
        },
        onError: (error) {
          // 处理错误：移除临时消息
          final filteredMessages = state.messages
              .where((msg) => msg.id != tempAiMessage.id)
              .toList();

          // 同时更新PageView的第一页
          List<List<MessageModel>> errorUpdatedPages = [...state.conversationPages];
          if (errorUpdatedPages.isNotEmpty) {
            errorUpdatedPages[0] = filteredMessages;
          }
          
          state = state.copyWith(
            messages: filteredMessages,
            conversationPages: errorUpdatedPages,
            status: ChatStatus.error,
            error: '发送消息失败: $error',
            isStreaming: false,
            streamingMessage: '',
          );
        },
      );
    } catch (e) {
      state = state.setError('发送消息失败: $e');
    }
  }

  // 停止AI生成
  Future<void> stopGeneration() async {
    try {
      await _repository.stopGeneration();
      _streamSubscription?.cancel();
      state = state.stopStreaming();
    } catch (e) {
      state = state.setError('停止生成失败: $e');
    }
  }

  // 删除消息
  Future<void> deleteMessage(String messageId) async {
    try {
      await _repository.deleteMessage(messageId);
      
      // 从状态中移除消息
      final updatedMessages = state.messages
          .where((msg) => msg.id != messageId)
          .toList();
      
      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.setError('删除消息失败: $e');
    }
  }

  // 删除会话
  Future<void> deleteConversation(String conversationId) async {
    try {
      await _repository.deleteConversation(conversationId);
      
      // 如果删除的是当前会话，清空当前会话和消息
      if (state.currentConversation?.id == conversationId) {
        state = state.copyWith(
          currentConversation: null,
          messages: [],
        );
      }
    } catch (e) {
      state = state.setError('删除会话失败: $e');
    }
  }

  // 更新会话标题
  Future<void> updateConversationTitle(String conversationId, String title) async {
    try {
      await _repository.updateConversationTitle(conversationId, title);
      
      // 更新当前会话状态
      if (state.currentConversation?.id == conversationId) {
        final updatedConversation = state.currentConversation!.copyWith(title: title);
        state = state.copyWith(currentConversation: updatedConversation);
      }
    } catch (e) {
      state = state.setError('更新会话标题失败: $e');
    }
  }

  // 更新会话名称
  Future<void> updateConversationName(String conversationId, String name) async {
    try {
      await _repository.updateConversationName(conversationId, name);
      
      // 更新当前会话状态
      if (state.currentConversation?.id == conversationId) {
        final updatedConversation = state.currentConversation!.copyWith(name: name);
        state = state.copyWith(currentConversation: updatedConversation);
      }
    } catch (e) {
      state = state.setError('更新会话名称失败: $e');
    }
  }

  // 播放TTS（直接获取音频文件）
  Future<void> playTTS(String text) async {
    try {
      print('🔊 正在获取TTS音频: ${text.substring(0, text.length.clamp(0, 50))}...');
      
      // 直接获取TTS音频文件路径
      final audioFilePath = await _repository.getTTSAudio(text);
      print('✅ 音频文件获取成功: $audioFilePath');
      
      // 验证文件是否存在
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        throw Exception('音频文件不存在: $audioFilePath');
      }
      
      final fileSize = await audioFile.length();
      print('📁 音频文件信息: 路径=$audioFilePath, 大小=$fileSize 字节');
      
      // 创建音频播放器并设置监听器
      final player = AudioPlayer();
      
      // 设置错误监听器
      player.onPlayerStateChanged.listen((state) {
        print('🎵 播放器状态变化: $state');
      });
      
      // 播放完成监听器
      player.onPlayerComplete.listen((_) async {
        print('✅ 音频播放完成');
        await player.dispose();
      });
      
      // 播放音频文件
      print('🎯 开始播放音频文件...');
      await player.play(DeviceFileSource(audioFilePath));
      print('🎵 音频播放已启动');
      
    } catch (e, stackTrace) {
      print('❌ 播放TTS失败: $e');
      print('📋 错误堆栈: $stackTrace');
      // 不要在UI中显示错误，只记录日志
    }
  }
  


  // 切换TTS自动播放设置
  Future<void> toggleTTSAutoPlay() async {
    final newValue = !state.autoPlayTTS;
    await StorageService.saveTTSAutoPlay(newValue);
    state = state.copyWith(autoPlayTTS: newValue);
  }

  // 清除错误状态
  void clearError() {
    state = state.clearError();
  }

  // 生成消息ID
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }

  // 提取原始消息ID（去掉_user或_assistant后缀）
  String _extractOriginalMessageId(String messageId) {
    if (messageId.endsWith('_user')) {
      return messageId.substring(0, messageId.length - 5); // 去掉'_user'
    } else if (messageId.endsWith('_assistant')) {
      return messageId.substring(0, messageId.length - 10); // 去掉'_assistant'
    }
    return messageId; // 如果没有后缀，直接返回原ID
  }

  // 异步保存会话 - 通过消息保存来触发会话更新
  void _saveConversationAsync(Conversation conversation) {
    // 简单记录日志，实际保存会在消息保存时进行
    print('会话信息已更新: ${conversation.id} - ${conversation.title}');
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}

// ChatNotifier的Provider
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.read(chatRepositoryProvider);
  return ChatNotifier(repository);
});