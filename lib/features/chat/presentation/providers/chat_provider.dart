import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
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
  StreamSubscription<String>? _ttsStreamSubscription;
  
  // 音频缓冲相关
  final Map<String, List<int>> _bufferedAudioData = {};
  final Map<String, String> _audioFileCache = {};
  final Map<String, bool> _isFetchingTTS = {};

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



  // 切换到指定会话
  Future<void> switchToConversation(Conversation conversation) async {
    try {
      print('🔄 切换到会话: ${conversation.displayName} (ID: ${conversation.id})');
      state = state.setLoading();
      
      final messages = await _repository.getMessages(conversation.id);
      
      print('✅ 成功加载会话消息，共 ${messages.length} 条消息');
      for (int i = 0; i < messages.length; i++) {
        final msg = messages[i];
        print('📝 消息 ${i + 1}: ${msg.type.name} - ${msg.content.substring(0, math.min(50, msg.content.length))}${msg.content.length > 50 ? '...' : ''}');
      }
      
      state = state.copyWith(
        currentConversation: conversation,
        messages: messages,
        status: ChatStatus.success,
      );
    } catch (e) {
      print('❌ 加载会话消息失败: $e');
      state = state.setError('加载会话消息失败: $e');
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
      state = state.copyWith(
        messages: [...state.messages, userMessage],
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
      state = state.copyWith(
        messages: [...state.messages, tempAiMessage],
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
              
              state = state.copyWith(messages: updatedMessages);
            }
          }
          
          // 更新临时消息的内容
          final updatedMessages = state.messages.map((msg) {
            if (msg.id == tempAiMessage.id) {
              return msg.copyWith(content: fullResponse);
            }
            return msg;
          }).toList();

          state = state.copyWith(
            messages: updatedMessages,
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
        },
        onError: (error) {
          // 处理错误：移除临时消息
          final filteredMessages = state.messages
              .where((msg) => msg.id != tempAiMessage.id)
              .toList();

          state = state.copyWith(
            messages: filteredMessages,
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

  // 播放TTS（简单版本）
  Future<void> playTTS(String text) async {
    try {
      print('正在获取TTS音频: ${text.substring(0, text.length.clamp(0, 50))}...');
      final audioData = await _repository.getTTSAudio(text);
      
      if (audioData.startsWith('data:audio/')) {
        // 这是Base64编码的音频数据
        print('收到Base64音频数据，长度: ${audioData.length}');
        // TODO: 实现Base64音频播放逻辑
        // 可以保存为临时文件然后播放
      } else {
        // 这是音频URL
        print('收到音频URL: $audioData');
        // TODO: 使用audioplayers播放URL
      }
    } catch (e) {
      print('播放TTS失败: $e');
      // 不要在UI中显示错误，只记录日志
    }
  }
  
  // 流式TTS播放（参考文档的实现）
  Future<void> fetchAndPlayStreamTTS({
    required String messageId,
    required String textContent,
    String voice = 'default',
  }) async {
    // 检查是否正在获取
    if (_isFetchingTTS[messageId] == true) return;
    
    // 检查文件缓存
    if (_audioFileCache.containsKey(messageId)) {
      final filePath = _audioFileCache[messageId]!;
      if (await File(filePath).exists()) {
        try {
          // TODO: 使用audioplayers播放缓存文件
          print('播放缓存的TTS文件: $filePath');
          return;
        } catch (e) {
          print('播放缓存文件失败: $e');
        }
      }
    }
    
    // 开始获取新的TTS数据
    _isFetchingTTS[messageId] = true;
    _bufferedAudioData.remove(messageId);
    
    try {
      _ttsStreamSubscription = _repository.getTTSAudioStream(
        text: textContent,
        messageId: messageId,
        voice: voice,
      ).listen(
        (base64AudioChunk) {
          _bufferAudioChunk(messageId, base64AudioChunk);
        },
        onDone: () async {
          // 流接收完毕，写入文件并播放
          await _finalizeTTSAudio(messageId);
        },
        onError: (error) {
          print('TTS流式获取错误: $error');
          _isFetchingTTS[messageId] = false;
        },
      );
    } catch (e) {
      print('启动TTS流式获取失败: $e');
      _isFetchingTTS[messageId] = false;
    }
  }
  
  // 缓冲音频数据片段
  void _bufferAudioChunk(String messageId, String base64AudioChunk) {
    try {
      final audioBytes = base64Decode(base64AudioChunk);
      if (!_bufferedAudioData.containsKey(messageId)) {
        _bufferedAudioData[messageId] = [];
      }
      _bufferedAudioData[messageId]!.addAll(audioBytes);
      print('为消息 $messageId 缓冲音频，总字节数: ${_bufferedAudioData[messageId]!.length}');
    } catch (e) {
      print('解码或缓冲音频片段失败 $messageId: $e');
    }
  }
  
  // 完成TTS音频并播放
  Future<void> _finalizeTTSAudio(String messageId) async {
    try {
      if (_bufferedAudioData.containsKey(messageId) && 
          _bufferedAudioData[messageId]!.isNotEmpty) {
        
        final audioBytes = Uint8List.fromList(_bufferedAudioData[messageId]!);
        final tempDir = await getTemporaryDirectory();
        final sanitizedMessageId = messageId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final tempFile = File('${tempDir.path}/tts_stream_audio_$sanitizedMessageId.mp3');
        
        try {
          await tempFile.writeAsBytes(audioBytes, flush: true);
          _audioFileCache[messageId] = tempFile.path;
          
          // TODO: 使用audioplayers播放音频文件
          print('TTS音频已保存并准备播放: ${tempFile.path}');
          
        } catch (e) {
          print('写入或播放临时文件失败: $e');
        }
      }
    } catch (e) {
      print('完成TTS音频处理失败: $e');
    } finally {
      _isFetchingTTS[messageId] = false;
    }
  }
  
  // 检查是否有缓冲的音频数据
  bool hasBufferedAudio(String messageId) {
    return _bufferedAudioData.containsKey(messageId) && 
           _bufferedAudioData[messageId]!.isNotEmpty;
  }
  
  // 清理音频缓存
  Future<void> clearAudioCache() async {
    try {
      for (final filePath in _audioFileCache.values) {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      _audioFileCache.clear();
      _bufferedAudioData.clear();
    } catch (e) {
      print('清理音频缓存失败: $e');
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

  // 异步保存会话 - 通过消息保存来触发会话更新
  void _saveConversationAsync(Conversation conversation) {
    // 简单记录日志，实际保存会在消息保存时进行
    print('会话信息已更新: ${conversation.id} - ${conversation.title}');
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _ttsStreamSubscription?.cancel();
    clearAudioCache(); // 清理音频缓存
    super.dispose();
  }
}

// ChatNotifier的Provider
final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repository = ref.read(chatRepositoryProvider);
  return ChatNotifier(repository);
}); 