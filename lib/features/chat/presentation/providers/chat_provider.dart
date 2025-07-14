import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../data/datasources/chat_remote_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../shared/models/message_model.dart';
import '../../domain/entities/conversation.dart';
import 'chat_state.dart';
import '../../../../core/storage/storage_service.dart';
import '../../../../core/services/tts_cache_service.dart';
import '../../../auth/presentation/providers/user_profile_provider.dart';

// 聊天相关的Provider
final chatRemoteDataSourceProvider = Provider<ChatRemoteDataSource>((ref) {
  return ChatRemoteDataSource();
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final remoteDataSource = ref.read(chatRemoteDataSourceProvider);
  return ChatRepositoryImpl(remoteDataSource);
});

// 聊天状态管理器
class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _repository;
  final Ref _ref;
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;
  static AudioPlayer? _audioPlayer;

  ChatNotifier(this._repository, this._ref) : super(const ChatState()) {
    _loadInitialData();
    _initAudioPlayer();
    _initTTSCache();
  }
  
  // 初始化TTS缓存服务
  Future<void> _initTTSCache() async {
    try {
      await TTSCacheService.instance.initialize();
      print('✅ TTS缓存服务初始化完成');
    } catch (e) {
      print('❌ TTS缓存服务初始化失败: $e');
    }
  }

  // 加载初始数据
  Future<void> _loadInitialData() async {    _initializeTTSSettings();
    // 不在初始化时加载会话，等待appId设置后再加载
  }

  // 初始化音频播放器
  void _initAudioPlayer() {
    if (_audioPlayer == null) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onPlayerStateChanged.listen((playerState) {
        print('🎵 播放器状态变化: $playerState');
        
        // 根据播放器状态更新TTS状态
        if (playerState == PlayerState.playing) {
          // 开始播放时设置播放状态，清除加载状态
          state = state.copyWith(
            isTTSLoading: false,
            isTTSPlaying: true,
          );
          print('🔍 播放器状态监听器: 播放开始，isTTSPlaying=true');
          
          // TTS开始播放时刷新用户资料（表示API调用成功）
          try {
            _ref.read(userProfileProvider.notifier).loadUserProfile();
            print('✅ TTS开始播放，已刷新用户资料');
          } catch (e) {
            print('⚠️ TTS开始播放时刷新用户资料失败: $e');
          }
        } else if (playerState == PlayerState.stopped) {
          // 停止播放时清除播放状态
          state = state.copyWith(
            isTTSPlaying: false,
          );
          print('🔍 播放器状态监听器: 播放停止，isTTSPlaying=false');
        }
      });
      _audioPlayer!.onPlayerComplete.listen((_) {
        print('✅ 音频播放完成');
        // 播放完成时清除所有TTS状态
        state = state.copyWith(
          isTTSLoading: false,
          isTTSPlaying: false,
        );
      });
    }
  }

  // 初始化TTS设置
  void _initializeTTSSettings() {
    final autoPlay = StorageService.getTTSAutoPlay();
    state = state.copyWith(autoPlayTTS: autoPlay);
  }

  // 设置应用信息
  void setAppInfo(String? appId, String? appName) {
    // 检查是否切换到了不同的应用
    final isAppChanged = state.appId != appId;
    
    if (isAppChanged) {
      print('🔄 检测到应用切换: ${state.appId} -> $appId，清理之前的状态');
      
      // 停止当前播放的TTS音频
      if (state.isTTSPlaying || state.isTTSLoading) {
        print('🛑 应用切换时停止TTS播放');
        stopTTS();
      }
      
      // 清理之前应用的状态
      state = ChatState(
        appId: appId,
        appName: appName,
        autoPlayTTS: state.autoPlayTTS, // 保留TTS设置
      );
      print('✅ 已清理之前应用的聊天状态');
    } else {
      // 同一个应用，只更新应用信息
      state = state.copyWith(appId: appId, appName: appName);
    }
    
    print('✅ 设置应用信息: appId=$appId, appName=$appName');
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

  // 切换到指定会话
  Future<void> switchToConversation(Conversation conversation) async {
    try {
      print('🔄 切换到会话: ${conversation.displayName} (ID: ${conversation.id})');
      
      // 停止当前播放的TTS音频
      if (state.isTTSPlaying || state.isTTSLoading) {
        print('🛑 会话切换时停止TTS播放');
        await stopTTS();
      }
      
      state = state.setLoading();
      
      // 加载最新的消息
      final result = await _repository.getMessagesWithPagination(
        conversation.id,
        limit: 5, // 初始加载5条消息
        firstId: null, // 不指定firstId，获取最新消息
        appId: state.appId,
      );
      
      final messages = result.$1; // 获取消息列表
      final hasMore = result.$2; // 获取是否还有更多消息
      
      print('✅ 成功加载会话消息，共 ${messages.length} 条消息');
      
      // 设置游标为最早的消息ID
      final firstId = messages.isNotEmpty 
          ? _extractOriginalMessageId(messages.first.id) 
          : null;
      
      state = state.copyWith(
        currentConversation: conversation,
        messages: messages,
        status: ChatStatus.success,
        firstId: firstId,
        hasMoreMessages: hasMore,
      );
    } catch (e) {
      print('❌ 加载会话消息失败: $e');
      state = state.setError('加载会话消息失败: $e');
    }
  }

  // 加载最新会话
  Future<void> loadLatestConversation() async {
    try {
      print('🚀 开始加载最新会话...');
      state = state.setLoading();
      
      // 获取最新会话
      final latestConversation = await _repository.getLatestConversation(appId: state.appId);
      
      if (latestConversation != null) {
        print('🎯 找到最新会话: ${latestConversation.displayName}');
        
        // 加载最新的消息
        final result = await _repository.getMessagesWithPagination(
          latestConversation.id,
          limit: 5, // 初始加载5条消息
          firstId: null, // 不指定firstId，获取最新消息
          appId: state.appId,
        );
        
        final messages = result.$1; // 获取消息列表
        final hasMore = result.$2; // 获取是否还有更多消息
        
        print('✅ 成功加载最新会话和消息，共 ${messages.length} 条消息');
        
        // 设置游标为最早的消息ID
        final firstId = messages.isNotEmpty 
            ? _extractOriginalMessageId(messages.first.id) 
            : null;
        
        state = state.copyWith(
          currentConversation: latestConversation,
          messages: messages,
          status: ChatStatus.success,
          firstId: firstId,
          hasMoreMessages: hasMore,
        );
        
        print('🎯 初始游标设置为: $firstId');
      } else {
        print('📝 没有找到现有会话，将创建新会话');
        state = state.copyWith(
          currentConversation: null,
          messages: [],
          status: ChatStatus.success,
          firstId: null,
          hasMoreMessages: false,
        );
      }
    } catch (e) {
      print('❌ 加载最新会话失败: $e');
      state = state.setError('加载最新会话失败: $e');
    }
  }

  // 加载更多历史消息
  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore || !state.hasMoreMessages || state.currentConversation == null) {
      return;
    }

    try {
      // 在状态更新之前保存当前的firstId
      final currentFirstId = state.firstId;
      final conversationId = state.currentConversation!.id;
      
      print('📖 开始加载更多历史消息，当前游标: $currentFirstId');
      print('🔍 [DEBUG] firstId参数检查: firstId=$currentFirstId, isNull=${currentFirstId == null}, isEmpty=${currentFirstId?.isEmpty ?? true}');
      
      state = state.copyWith(isLoadingMore: true);
      
      // 使用保存的firstId加载历史消息
      final result = await _repository.getMessagesWithPagination(
        conversationId,
        limit: 5, // 每次加载更多消息
        firstId: currentFirstId,
        appId: state.appId,
      );
      
      final newMessages = result.$1; // 获取消息列表
      final hasMore = result.$2; // 获取是否还有更多消息
      
      print('📋 获取到 ${newMessages.length} 条新消息');
      print('🔍 当前游标: $currentFirstId');
      print('📊 API返回hasMore: $hasMore');
      
      if (newMessages.isNotEmpty) {
        final updatedMessages = [...newMessages, ...state.messages];
        
        // 更新游标为最早的消息ID
        final newFirstId = newMessages.isNotEmpty 
            ? _extractOriginalMessageId(newMessages.first.id) 
            : currentFirstId;
        
        state = state.copyWith(
          messages: updatedMessages,
          firstId: newFirstId,
          hasMoreMessages: hasMore,
          isLoadingMore: false,
        );
        
        print('🎯 游标已更新为: $newFirstId');
        print('✅ 成功加载 ${newMessages.length} 条历史消息，总消息数: ${updatedMessages.length}');
      } else {
        // 没有更多消息了
        print('⚠️ 没有获取到新消息，设置hasMoreMessages=false');
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
        hasMoreMessages: false, // 出错时也设置为false，避免无限重试
        error: '加载更多消息失败: $e',
      );
    }
  }

  // 检查是否可以加载更多消息
  bool get canLoadMoreMessages => state.hasMoreMessages && !state.isLoadingMore;

  // 发送消息（流式响应，带type参数）
  Future<void> sendMessageStreamWithType(String content, String type) async {
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
      // 创建用户消息和AI消息，确保id唯一
      final baseId = _generateMessageId();
      final userMessage = MessageModel(
        id: '${baseId}_user',
        content: content,
        type: MessageType.user,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        conversationId: conversationId,
      );

      // 创建临时AI消息用于显示流式响应
      final tempAiMessage = MessageModel(
        id: '${baseId}_ai',
        content: '正在思考中...',
        type: MessageType.ai,
        status: MessageStatus.received,
        timestamp: DateTime.now(),
        conversationId: conversationId,
      );

      // 添加用户消息和临时AI消息到消息列表末尾
      final updatedMessages = [...state.messages, userMessage, tempAiMessage];
      
      // 立即更新状态，显示用户消息和思考中的AI消息
      state = state.copyWith(
        messages: updatedMessages,
        status: ChatStatus.sending,
        isStreaming: true,
      );

      // 保存用户消息
      await _repository.saveMessage(userMessage);

      // 设置AI思考中状态
      state = state.copyWith(status: ChatStatus.thinking);

      String fullResponse = '';

      // 开始流式响应，传递type参数
      _streamSubscription = _repository.sendMessageStreamWithConversationIdAndType(
        message: content,
        conversationId: conversationId,
        type: type,
        appId: state.appId,
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
              final updatedMessages = state.messages.map((msg) {
                if (msg.id == userMessage.id) {
                  return msg.copyWith(conversationId: newConversationId);
                } else if (msg.id == tempAiMessage.id) {
                  return msg.copyWith(conversationId: newConversationId);
                }
                return msg;
              }).toList();
              
              state = state.copyWith(messages: updatedMessages);
            }
          }
          
          // 更新临时消息的内容（第一个chunk时清除"思考中"提示）
          final displayContent = fullResponse.isEmpty ? '正在输入...' : fullResponse;
          
          // 更新临时AI消息的内容
          final updatedMessages = state.messages.map((msg) {
            if (msg.id == tempAiMessage.id) {
              return msg.copyWith(content: displayContent);
            }
            return msg;
          }).toList();
          
          state = state.copyWith(
            messages: updatedMessages,
            status: ChatStatus.streaming,
            streamingMessage: fullResponse,
          );
        },
        onDone: () async {
          // 流式响应完成，直接替换临时AI消息内容和状态，不再插入新气泡
          final updatedMessages = state.messages.map((msg) {
            if (msg.id == tempAiMessage.id) {
              return msg.copyWith(
                content: fullResponse,
                status: MessageStatus.received,
              );
            }
            return msg;
          }).toList();

          await _repository.saveMessage(
            tempAiMessage.copyWith(content: fullResponse, status: MessageStatus.received),
          );

          state = state.copyWith(
            messages: updatedMessages,
            status: ChatStatus.success,
            isStreaming: false,
            streamingMessage: '',
          );

          // 如果开启了自动播放，播放TTS
          if (state.autoPlayTTS && fullResponse.isNotEmpty) {
            playTTS(fullResponse);
          }
          
          // AI回复完成后，刷新用户资料（包括token余额）
          try {
            // 通过ref刷新用户资料
            _ref.read(userProfileProvider.notifier).loadUserProfile();
            print('✅ AI回复完成，已刷新用户资料');
          } catch (e) {
            print('⚠️ 刷新用户资料失败: $e');
          }
        },
        onError: (error) {
          // 处理错误：移除临时AI消息，并将用户消息标记为失败
          print('❌ 消息发送失败: $error');
          
          final errorUpdatedMessages = state.messages
              .where((msg) => msg.id != tempAiMessage.id)
              .map((msg) {
                // 将用户消息标记为失败，并添加错误信息
                if (msg.id == userMessage.id) {
                  // 清理错误消息，移除Exception前缀
                  String cleanErrorMessage = error.toString();
                  if (cleanErrorMessage.startsWith('Exception: ')) {
                    cleanErrorMessage = cleanErrorMessage.substring(11);
                  }
                  return msg.copyWith(
                    status: MessageStatus.failed,
                    errorMessage: cleanErrorMessage,
                  );
                }
                return msg;
              })
              .toList();
          
          state = state.copyWith(
            messages: errorUpdatedMessages,
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
      // 创建用户消息和AI消息，确保id唯一
      final baseId = _generateMessageId();
      final userMessage = MessageModel(
        id: '${baseId}_user',
        content: content,
        type: MessageType.user,
        status: MessageStatus.sent,
        timestamp: DateTime.now(),
        conversationId: conversationId,
      );

      // 创建临时AI消息用于显示流式响应
      final tempAiMessage = MessageModel(
        id: '${baseId}_ai',
        content: '正在思考中...',
        type: MessageType.ai,
        status: MessageStatus.received,
        timestamp: DateTime.now(),
        conversationId: conversationId,
      );

      // 添加用户消息和临时AI消息到消息列表末尾
      final updatedMessages = [...state.messages, userMessage, tempAiMessage];
      
      // 立即更新状态，显示用户消息和思考中的AI消息
      state = state.copyWith(
        messages: updatedMessages,
        status: ChatStatus.sending,
        isStreaming: true,
      );

      // 保存用户消息
      await _repository.saveMessage(userMessage);

      // 设置AI思考中状态
      state = state.copyWith(status: ChatStatus.thinking);

      String fullResponse = '';

      // 开始流式响应
      _streamSubscription = _repository.sendMessageStreamWithConversationId(
        message: content,
        conversationId: conversationId,
        appId: state.appId,
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
              final updatedMessages = state.messages.map((msg) {
                if (msg.id == userMessage.id) {
                  return msg.copyWith(conversationId: newConversationId);
                } else if (msg.id == tempAiMessage.id) {
                  return msg.copyWith(conversationId: newConversationId);
                }
                return msg;
              }).toList();
              
              state = state.copyWith(messages: updatedMessages);
            }
          }
          
          // 更新临时消息的内容（第一个chunk时清除"思考中"提示）
          final displayContent = fullResponse.isEmpty ? '正在输入...' : fullResponse;
          
          // 更新临时AI消息的内容
          final updatedMessages = state.messages.map((msg) {
            if (msg.id == tempAiMessage.id) {
              return msg.copyWith(content: displayContent);
            }
            return msg;
          }).toList();
          
          state = state.copyWith(
            messages: updatedMessages,
            status: ChatStatus.streaming,
            streamingMessage: fullResponse,
          );
        },
        onDone: () async {
          // 流式响应完成，直接替换临时AI消息内容和状态，不再插入新气泡
          final updatedMessages = state.messages.map((msg) {
            if (msg.id == tempAiMessage.id) {
              return msg.copyWith(
                content: fullResponse,
                status: MessageStatus.received,
              );
            }
            return msg;
          }).toList();

          await _repository.saveMessage(
            tempAiMessage.copyWith(content: fullResponse, status: MessageStatus.received),
          );

          state = state.copyWith(
            messages: updatedMessages,
            status: ChatStatus.success,
            isStreaming: false,
            streamingMessage: '',
          );

          // 如果开启了自动播放，播放TTS
          if (state.autoPlayTTS && fullResponse.isNotEmpty) {
            playTTS(fullResponse);
          }
          
          // AI回复完成后，刷新用户资料（包括token余额）
          try {
            // 通过ref刷新用户资料
            _ref.read(userProfileProvider.notifier).loadUserProfile();
            print('✅ AI回复完成，已刷新用户资料');
          } catch (e) {
            print('⚠️ 刷新用户资料失败: $e');
          }
        },
        onError: (error) {
          // 处理错误：移除临时AI消息，并将用户消息标记为失败
          print('❌ 消息发送失败: $error');
          
          final errorUpdatedMessages = state.messages
              .where((msg) => msg.id != tempAiMessage.id)
              .map((msg) {
                // 将用户消息标记为失败，并添加错误信息
                if (msg.id == userMessage.id) {
                  // 清理错误消息，移除Exception前缀
                  String cleanErrorMessage = error.toString();
                  if (cleanErrorMessage.startsWith('Exception: ')) {
                    cleanErrorMessage = cleanErrorMessage.substring(11);
                  }
                  return msg.copyWith(
                    status: MessageStatus.failed,
                    errorMessage: cleanErrorMessage,
                  );
                }
                return msg;
              })
              .toList();
          
          state = state.copyWith(
            messages: errorUpdatedMessages,
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

  // 重试发送消息
  Future<void> retryMessage(String messageId) async {
    try {
      // 找到失败的消息
      final failedMessage = state.messages.firstWhere(
        (msg) => msg.id == messageId,
        orElse: () => throw Exception('未找到要重试的消息'),
      );
      
      // 只能重试用户消息
      if (failedMessage.type != MessageType.user) {
        throw Exception('只能重试用户消息');
      }
      
      // 移除失败的消息
      final updatedMessages = state.messages
          .where((msg) => msg.id != messageId)
          .toList();
      
      state = state.copyWith(messages: updatedMessages);
      
      // 重新发送消息
      await sendMessageStream(failedMessage.content);
      
    } catch (e) {
      print('❌ 重试消息失败: $e');
      state = state.setError('重试消息失败: $e');
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
      await _repository.deleteConversation(conversationId, appId: state.appId);
      
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
      await _repository.updateConversationTitle(conversationId, title, appId: state.appId);
      
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
      await _repository.updateConversationName(conversationId, name, appId: state.appId);
      
      // 更新当前会话状态
      if (state.currentConversation?.id == conversationId) {
        final updatedConversation = state.currentConversation!.copyWith(name: name);
        state = state.copyWith(currentConversation: updatedConversation);
      }
    } catch (e) {
      state = state.setError('更新会话名称失败: $e');
    }
  }

  // 播放TTS（带缓存功能）
  Future<void> playTTS(String text) async {
    // 如果正在播放，先停止
    if (state.isTTSPlaying) {
      await stopTTS();
    }
    
    try {
      print('🔊 正在获取TTS音频: ${text.substring(0, text.length.clamp(0, 50))}...');
      
      // 设置加载状态
      state = state.copyWith(
        isTTSLoading: true,
        isTTSPlaying: false,
      );
      print('🔍 TTS加载开始: isTTSLoading=true');
      
      // 确保音频播放器已初始化
      _initAudioPlayer();
      
      // 停止当前播放
      if (_audioPlayer!.state == PlayerState.playing) {
        await _audioPlayer!.stop();
      }
      
      String audioFilePath;
      
      // 首先检查缓存
      final cachedPath = await TTSCacheService.instance.getCachedAudioPath(text);
      if (cachedPath != null) {
        print('🎯 使用缓存音频文件: $cachedPath');
        audioFilePath = cachedPath;
      } else {
        print('📡 从服务器获取TTS音频...');
        // 从服务器获取音频文件
        final tempAudioPath = await _repository.getTTSAudio(text, appId: state.appId);
        print('✅ 音频文件获取成功: $tempAudioPath');
        
        // 缓存音频文件
        try {
          audioFilePath = await TTSCacheService.instance.cacheAudioFile(text, tempAudioPath);
          print('💾 音频文件已缓存: $audioFilePath');
          
          // 删除临时文件
          final tempFile = File(tempAudioPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('🗑️ 临时文件已删除: $tempAudioPath');
          }
        } catch (cacheError) {
          print('⚠️ 缓存音频文件失败: $cacheError，使用临时文件');
          audioFilePath = tempAudioPath;
        }
      }
      
      // 验证文件是否存在
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        throw Exception('音频文件不存在: $audioFilePath');
      }
      
      final fileSize = await audioFile.length();
      print('📁 音频文件信息: 路径=$audioFilePath, 大小=$fileSize 字节');
      
      // 验证音频文件格式
      final audioBytes = await audioFile.readAsBytes();
      if (audioBytes.length < 10) {
        throw Exception('音频文件太小，可能损坏');
      }
      
      // 检查MP3文件头
      final header = String.fromCharCodes(audioBytes.take(3));
      if (header != 'ID3' && audioBytes[0] != 0xFF) {
        print('⚠️ 音频文件格式可能不标准，尝试播放...');
      }
      
      // 播放音频文件
      print('🎯 开始播放音频文件...');
      
      await _audioPlayer!.play(DeviceFileSource(audioFilePath));
      print('🎵 音频播放已启动');
      
      // 播放成功，状态将在onPlayerStateChanged中自动更新
      print('🎯 TTS播放启动成功，等待播放器状态更新');
      
    } catch (e, stackTrace) {
      print('❌ 播放TTS失败: $e');
      print('📋 错误堆栈: $stackTrace');
      
      // 立即清除所有TTS状态
      state = state.copyWith(
        isTTSLoading: false,
        isTTSPlaying: false,
      );
      
      // 尝试重新初始化播放器
      try {
        await _audioPlayer?.dispose();
        _audioPlayer = null;
        _initAudioPlayer();
        print('🔄 音频播放器已重新初始化');
      } catch (reinitError) {
        print('❌ 重新初始化播放器失败: $reinitError');
      }
    }
  }
  
  // 停止TTS播放
  Future<void> stopTTS() async {
    try {
      print('🛑 停止TTS播放');
      if (_audioPlayer != null && _audioPlayer!.state == PlayerState.playing) {
        await _audioPlayer!.stop();
      }
      // 清除所有TTS状态
      state = state.copyWith(
        isTTSLoading: false,
        isTTSPlaying: false,
      );
      print('✅ TTS状态已清除');
    } catch (e) {
      print('❌ 停止TTS播放失败: $e');
      // 即使停止失败，也要清除状态
      state = state.copyWith(
        isTTSLoading: false,
        isTTSPlaying: false,
      );
    }
  }
  


  // 切换TTS自动播放设置
  Future<void> toggleTTSAutoPlay() async {
    final newValue = !state.autoPlayTTS;
    await StorageService.saveTTSAutoPlay(newValue);
    state = state.copyWith(autoPlayTTS: newValue);
  }
  
  // 获取TTS缓存统计信息
  Future<Map<String, dynamic>> getTTSCacheStats() async {
    try {
      return await TTSCacheService.instance.getCacheStats();
    } catch (e) {
      print('❌ 获取TTS缓存统计失败: $e');
      return {
        'error': e.toString(),
        'fileCount': 0,
        'totalSizeMB': 0.0,
      };
    }
  }
  
  // 清空TTS缓存
  Future<void> clearTTSCache() async {
    try {
      await TTSCacheService.instance.clearAllCache();
      print('✅ TTS缓存已清空');
    } catch (e) {
      print('❌ 清空TTS缓存失败: $e');
    }
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
    _audioPlayer?.dispose();
    _audioPlayer = null;
    super.dispose();
  }

  // 初始化聊天，加载最新会话
  Future<void> initializeChat() async {
    try {
      print('🚀 [ChatPage] 开始初始化聊天...');
      
      state = state.copyWith(
        status: ChatStatus.loading,
        error: null,
      );

      // 直接尝试获取最新会话，不使用本地回退
      final latestConversation = await _repository.getLatestConversation(appId: state.appId);
      
      if (latestConversation != null) {
        print('✅ 找到最新会话: ${latestConversation.id}');
        await switchToConversation(latestConversation);
      } else {
        print('⚠️ 未找到任何会话，准备开始新对话');
        state = state.copyWith(
          currentConversation: null,
          messages: [],
          status: ChatStatus.initial,
        );
      }
    } catch (e) {
      print('❌ 初始化聊天失败: $e');
      
      // 根据错误类型提供不同的用户提示
      String userFriendlyError = _getUserFriendlyError(e);
      
      state = state.copyWith(
        status: ChatStatus.error,
        error: userFriendlyError,
      );
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
}

// ChatNotifier的Provider
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.read(chatRepositoryProvider);
  return ChatNotifier(repository, ref);
});