# AI对话功能流式响应实现文档

## 项目概述

本项目是一个基于Flutter开发的AI对话应用，集成了Dify API，实现了实时流式响应、TTS语音合成、会话管理等功能。项目采用Clean Architecture架构模式，使用GetX进行状态管理。

## 核心技术栈

- **框架**: Flutter
- **状态管理**: GetX
- **网络请求**: Dio + HTTP
- **音频播放**: AudioPlayer
- **架构模式**: Clean Architecture (表现层、领域层、数据层)
- **API集成**: Dify API

## 项目架构

```
lib/
├── presentation/          # 表现层
│   ├── views/            # UI界面
│   └── viewmodels/       # 视图模型
├── domain/               # 领域层
│   ├── entities/         # 实体
│   ├── repositories/     # 仓库接口
│   └── usecases/         # 用例
├── data/                 # 数据层
│   ├── datasources/      # 数据源
│   ├── models/           # 数据模型
│   └── repositories/     # 仓库实现
└── core/                 # 核心层
    ├── network/          # 网络配置
    ├── services/         # 服务
    └── utils/            # 工具类
```

## 流式响应处理核心实现

### 1. API配置 (Constants)

```dart
class Constants {
  static const String baseUrl = 'http://api.classhorse.top';
  static const String appId = '53868c40-a867-407b-a549-a8f2c689f802';
  static const String conversationsEndpoint = '$apiPrefix/installed-apps/$appId/conversations';
  static const String messagesEndpoint = '$apiPrefix/installed-apps/$appId/messages';
  static const String textToAudioEndpoint = '$apiPrefix/installed-apps/$appId/text-to-audio';
  
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
}
```

### 2. 数据源层 - 流式响应处理

#### ConversationDataSource 实现

```dart
@override
Stream<ChatMessageEvent> sendChatMessage({
  required String appId,
  String? conversationId,
  required String query,
  String? parentMessageId,
  List<dynamic>? files,
  Map<String, dynamic>? inputs,
}) async* {
  try {
    final url = '${Constants.baseUrl}/console/api/installed-apps/$appId/chat-messages';
    
    // 构建请求体
    final Map<String, dynamic> bodyMap = {
      'response_mode': 'streaming',  // 关键：启用流式响应
      'query': query,
      'files': files ?? [],
      'inputs': inputs ?? {},
      'conversation_id': conversationId ?? '',
    };
    
    // 设置请求头
    final request = http.Request('POST', Uri.parse(url));
    request.headers.addAll({
      'Accept': '*/*',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'Cookie': 'locale=${Constants.defaultLanguage}',
    });
    
    request.body = jsonEncode(bodyMap);
    final streamedResponse = await request.send();
    
    // 处理流式响应
    final responseStream = streamedResponse.stream
        .transform(utf8.decoder)           // UTF-8解码
        .transform(const LineSplitter());  // 按行分割
        
    await for (final line in responseStream) {
      if (line.startsWith('data: ')) {
        final jsonData = line.substring(6); // 移除 'data: ' 前缀
        try {
          final parsedData = jsonDecode(jsonData);
          yield ChatMessageEvent.fromJson(parsedData);
        } catch (e) {
          print('解析响应数据失败: $e');
        }
      }
    }
  } catch (e) {
    throw DioException(error: '发送消息异常: $e');
  }
}
```

### 3. 消息事件模型

#### ChatMessageEvent 数据结构

```dart
class ChatMessageEvent {
  final String? event;           // 事件类型
  final String? conversationId;  // 会话ID
  final String? messageId;       // 消息ID
  final int? createdAt;          // 创建时间
  final String? taskId;          // 任务ID
  final String? answer;          // AI回答内容
  final String? audio;           // 音频数据(Base64)
  
  // 事件类型判断方法
  bool isMessageEvent() => event == 'message';
  bool isAudioEvent() => event == 'tts_message';
  bool isWorkflowEvent() => event == 'workflow_started' || event == 'workflow_finished';
  bool isMessageEndEvent() => event == 'message_end';
}
```

### 4. 视图模型层 - 消息处理

#### MessageViewModel 核心功能

```dart
class MessageViewModel extends GetxController {
  // 响应式状态
  final RxList<MessageEntity> _messages = <MessageEntity>[].obs;
  final RxString _tempMessageId = ''.obs;
  final RxBool _isResponseGenerating = false.obs;
  
  // 音频相关状态
  final AudioPlayer _audioPlayer = AudioPlayer();
  final RxMap<String, List<int>> _bufferedAudioData = <String, List<int>>{}.obs;
  final RxMap<String, String> _audioFileCache = <String, String>{}.obs;
  
  // 消息流订阅管理
  StreamSubscription? _messageStreamSubscription;
  
  /// 发送聊天消息并获取流式响应
  Stream<ChatMessageEventEntity> sendChatMessage({
    required String appId,
    String? conversationId,
    required String query,
    String? parentMessageId,
    List<dynamic>? files,
    Map<String, dynamic>? inputs,
  }) {
    try {
      // 取消可能存在的订阅
      _messageStreamSubscription?.cancel();
      _messageStreamSubscription = null;
      
      // 设置响应生成状态
      _isResponseGenerating.value = true;
      
      // 获取消息流
      final messageStream = sendChatMessageUseCase.execute(
        appId: appId,
        conversationId: conversationId,
        query: query,
        parentMessageId: parentMessageId,
        files: files,
        inputs: inputs,
      );
      
      // 创建广播流控制器
      final controller = StreamController<ChatMessageEventEntity>.broadcast();
      
      // 订阅消息流
      _messageStreamSubscription = messageStream.listen(
        (event) {
          if (!controller.isClosed) {
            controller.add(event);
          }
        },
        onError: (e) {
          _error.value = e.toString();
          _isResponseGenerating.value = false;
          if (!controller.isClosed) {
            controller.addError(e);
            controller.close();
          }
        },
        onDone: () {
          _isResponseGenerating.value = false;
          if (!controller.isClosed) {
            controller.close();
          }
          _messageStreamSubscription = null;
        },
      );
      
      return controller.stream;
    } catch (e) {
      _error.value = e.toString();
      _isResponseGenerating.value = false;
      rethrow;
    }
  }
}
```

### 5. 页面展示层 - 流式响应处理

#### ChatScreen 消息发送流程

```dart
// 1. 用户输入验证
final messageText = _messageController.text.trim();
if (messageText.isEmpty) {
  Get.snackbar('提示', '请输入消息内容');
  return;
}

// 2. 清空输入框并添加用户消息
_messageController.clear();
final userMessage = MessageModel(
  id: 'user_${DateTime.now().millisecondsSinceEpoch}',
  conversationId: _selectedConversation?.id ?? '',
  query: messageText,
  answer: "",
  status: 'completed',
  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
);
msgViewModel.addUserMessage(userMessage);
_scrollToBottom();

// 3. 显示临时AI回复
final tempAiMessage = MessageModel(
  id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
  conversationId: _selectedConversation?.id ?? '',
  query: "",
  answer: "正在思考中...",
  status: 'processing',
  createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
);
msgViewModel.addTempAiMessage(tempAiMessage);

// 4. 订阅消息流并处理响应
String completeAnswer = '';
String? currentAiMessageAuthoritativeId;
final String clientSideTempMessageId = msgViewModel.tempMessageId;

msgViewModel.sendChatMessage(
  appId: Constants.appId,
  conversationId: _selectedConversation?.id,
  query: messageText,
).listen(
  (event) {
    // 处理权威消息ID
    if (event.messageId != null && !event.messageId!.startsWith('temp_')) {
      if (currentAiMessageAuthoritativeId == null) {
        currentAiMessageAuthoritativeId = event.messageId;
        msgViewModel.updateTempMessageIdAuthoritatively(
          clientSideTempMessageId,
          currentAiMessageAuthoritativeId!,
        );
      }
    }
    
    // 处理新会话创建
    if (_selectedConversation == null && 
        event.conversationId != null && 
        event.conversationId!.isNotEmpty) {
      msgViewModel.setCurrentConversationId(event.conversationId!);
      
      // 创建临时会话对象
      final tempConversation = ConversationEntity(
        id: event.conversationId!,
        name: '新会话 ${DateTime.now().toString().substring(0, 16)}',
        updatedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        status: 'normal',
        inputs: {},
        introduction: '',
      );
      
      setState(() {
        _selectedConversation = tempConversation;
      });
      
      // 刷新会话列表
      final conversationViewModel = Get.find<ConversationViewModel>();
      conversationViewModel.refreshConversations();
    }
    
    // 处理文本消息
    if (event.isMessageEvent() && event.answer != null) {
      completeAnswer += event.answer!;
      msgViewModel.updateTempAiMessage(completeAnswer);
      _scrollToBottom();
    }
    
    // 处理TTS音频
    if (event.event == 'tts_message') {
      final String idForAudioBuffer = currentAiMessageAuthoritativeId ?? 
                                     event.messageId ?? '';
      if (idForAudioBuffer.isNotEmpty && 
          event.audio != null && 
          event.audio!.isNotEmpty) {
        msgViewModel.bufferAudioChunk(idForAudioBuffer, event.audio!);
      }
    }
    
    // 处理流结束
    if (event.event == 'message_end') {
      msgViewModel.finalizeTempAiMessage(completeAnswer);
      _scrollToBottom();
    }
  },
  onDone: () {
    // 确保消息最终化
    msgViewModel.finalizeTempAiMessage(completeAnswer);
    _scrollToBottom();
    
    // 播放音频（如果有缓冲的音频数据）
    final String? idToPlayOnDone = currentAiMessageAuthoritativeId;
    if (idToPlayOnDone != null && msgViewModel.hasBufferedAudio(idToPlayOnDone)) {
      msgViewModel.playAudio(idToPlayOnDone);
    }
    
    currentAiMessageAuthoritativeId = null;
  },
  onError: (e) {
    msgViewModel.removeTempAiMessage();
    Get.snackbar('错误', '发送消息失败: $e');
  },
);
```

## TTS语音合成流式处理

### 1. 音频数据缓冲

```dart
/// 累积音频数据片段
void bufferAudioChunk(String messageId, String base64AudioChunk) {
  try {
    final audioBytes = base64Decode(base64AudioChunk);
    if (!_bufferedAudioData.containsKey(messageId)) {
      _bufferedAudioData[messageId] = [];
    }
    _bufferedAudioData[messageId]!.addAll(audioBytes);
    _bufferedAudioData.refresh();
    print('Buffered audio for $messageId, total bytes: ${_bufferedAudioData[messageId]!.length}');
  } catch (e) {
    print('Error decoding or buffering audio chunk for $messageId: $e');
  }
}
```

### 2. 流式TTS音频获取

```dart
/// API客户端流式TTS实现
Stream<Uint8List> streamTextToAudio({
  required String text,
  required String messageId,
  String voice = 'sambert-cally-v1',
}) async* {
  final Map<String, dynamic> requestData = {
    'message_id': messageId,
    'streaming': true,
    'voice': voice,
    'text': text,
  };
  
  try {
    final response = await _dio.post(
      Constants.textToAudioEndpoint,
      data: requestData,
      options: dio.Options(
        responseType: dio.ResponseType.stream, // 关键：流式响应
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );
    
    if (response.statusCode == 200 && response.data != null) {
      final responseStream = response.data.stream as Stream<List<int>>;
      await for (final chunk in responseStream) {
        yield Uint8List.fromList(chunk);
      }
    }
  } catch (e) {
    print('Error in streamTextToAudio: $e');
    rethrow;
  }
}
```

### 3. 音频播放管理

```dart
/// 获取TTS音频并播放
Future<void> fetchAndPlayTTS({
  required String uiMessageId,
  required String textContent,
  String? originalApiMessageId,
  String voice = 'sambert-zhimiao-emo-v1',
}) async {
  // 检查是否正在获取
  if (isFetchingTTS(uiMessageId)) return;
  
  // 检查文件缓存
  if (_audioFileCache.containsKey(uiMessageId) && 
      await File(_audioFileCache[uiMessageId]!).exists()) {
    try {
      _currentPlayingAudioMessageId.value = uiMessageId;
      await _audioPlayer.play(DeviceFileSource(_audioFileCache[uiMessageId]!));
    } catch (e) {
      print('Error playing cached file: $e');
    }
    return;
  }
  
  // 开始获取新的TTS数据
  _isFetchingTTS[uiMessageId] = true;
  _bufferedAudioData.remove(uiMessageId);
  
  try {
    final apiClient = Get.find<ApiClient>();
    final audioStream = apiClient.streamTextToAudio(
      text: textContent,
      messageId: originalApiMessageId ?? uiMessageId,
      voice: voice,
    );
    
    // 监听流并缓冲数据
    await for (final audioChunkBytes in audioStream) {
      if (audioChunkBytes.isNotEmpty) {
        final base64AudioChunk = base64Encode(audioChunkBytes);
        bufferAudioChunk(uiMessageId, base64AudioChunk);
      }
    }
    
    // 流接收完毕，写入文件并播放
    if (hasBufferedAudio(uiMessageId)) {
      final audioBytes = Uint8List.fromList(_bufferedAudioData[uiMessageId]!);
      final tempDir = await getTemporaryDirectory();
      final sanitizedMessageId = uiMessageId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final tempFile = File('${tempDir.path}/tts_stream_audio_$sanitizedMessageId.mp3');
      
      try {
        await tempFile.writeAsBytes(audioBytes, flush: true);
        _currentPlayingAudioMessageId.value = uiMessageId;
        await _audioPlayer.play(DeviceFileSource(tempFile.path));
        _audioFileCache[uiMessageId] = tempFile.path; // 缓存文件路径
      } catch (e) {
        print('Error writing or playing temp file: $e');
      }
    }
  } catch (e) {
    print('Error fetching TTS: $e');
  } finally {
    _isFetchingTTS[uiMessageId] = false;
  }
}
```

## 页面UI展示特性

### 1. 实时消息更新

- **流式文本显示**: AI回复内容实时追加显示
- **打字机效果**: 模拟真实对话体验
- **自动滚动**: 新消息自动滚动到底部
- **状态指示**: 显示"正在思考中..."等状态

### 2. 消息状态管理

- **临时消息**: 使用客户端生成的临时ID
- **权威ID更新**: 接收到服务器ID后更新消息
- **状态转换**: processing → completed
- **错误处理**: 失败时移除临时消息

### 3. 会话管理

- **新会话创建**: 自动检测并创建新会话
- **会话列表刷新**: 实时更新会话列表
- **会话切换**: 支持多会话管理

### 4. 音频功能

- **实时TTS**: 流式语音合成
- **音频缓存**: 本地文件缓存机制
- **播放控制**: 播放/暂停/停止
- **状态同步**: 音频播放状态与UI同步

## 错误处理机制

### 1. 网络错误处理

```dart
// 流式响应错误处理
onError: (e) {
  msgViewModel.removeTempAiMessage();
  Get.snackbar(
    '错误',
    '发送消息失败: $e',
    backgroundColor: Colors.red,
    colorText: Colors.white,
  );
}
```

### 2. 音频错误处理

```dart
// TTS获取错误处理
catch (e) {
  print('Error fetching TTS: $e');
  Get.snackbar(
    '错误', 
    '获取语音时发生错误: ${e.toString()}',
    backgroundColor: Colors.red,
    colorText: Colors.white
  );
} finally {
  _isFetchingTTS[uiMessageId] = false;
}
```

### 3. 认证错误处理

```dart
// 令牌刷新机制
if (response.statusCode == 401) {
  try {
    await _refreshToken();
    _retryPendingRequests();
  } catch (e) {
    _handleLogout();
    _rejectAllRequests();
  }
}
```

## 性能优化策略

### 1. 内存管理

- **音频缓存清理**: 定期清理不需要的音频文件
- **消息分页**: 限制内存中的消息数量
- **流订阅管理**: 及时取消不需要的订阅

### 2. 网络优化

- **连接复用**: 使用持久连接
- **超时设置**: 合理的连接和接收超时
- **重试机制**: 自动重试失败的请求

### 3. UI优化

- **响应式更新**: 使用GetX的响应式状态管理
- **局部刷新**: 只更新需要变化的UI组件
- **异步操作**: 避免阻塞UI线程

## 总结

本项目实现了一个完整的AI对话系统，具有以下特点：

1. **实时流式响应**: 基于Server-Sent Events (SSE)的流式数据处理
2. **语音合成**: 集成TTS功能，支持流式音频生成和播放
3. **状态管理**: 使用GetX进行响应式状态管理
4. **错误处理**: 完善的错误处理和用户反馈机制
5. **性能优化**: 内存管理、网络优化和UI优化
6. **架构清晰**: Clean Architecture确保代码的可维护性和可扩展性

该实现为Flutter应用集成AI对话功能提供了一个完整的解决方案，可以作为类似项目的参考和基础。