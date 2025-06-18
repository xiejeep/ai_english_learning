import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/app_constants.dart';


class ChatRemoteDataSource {
  final Dio _dio = DioClient.instance;
  
  // 用于取消流式请求的取消令牌
  CancelToken? _cancelToken;
  
  // 发送消息并获取流式回复
  Stream<String> sendMessageStream({
    required String message,
    required String conversationId,
    required String userId,
  }) async* {
    await for (final data in sendMessageStreamWithConversationId(
      message: message,
      conversationId: conversationId,
      userId: userId,
    )) {
      final content = data['content'] as String?;
      if (content != null && content.isNotEmpty) {
        yield content;
      }
    }
  }

  // 改进的流式响应，返回包含消息内容和会话ID的数据
  Stream<Map<String, dynamic>> sendMessageStreamWithConversationId({
    required String message,
    required String conversationId,
    required String userId,
  }) async* {
    try {
      _cancelToken = CancelToken();
      
      final response = await _dio.post(
        AppConstants.difychatPath,
        data: {
          'inputs': {},
          'query': message,
          'response_mode': 'streaming',
          'conversation_id': conversationId, // 总是传递字符串，空时为 ""
          'user': userId,
        },
        options: Options(
          responseType: ResponseType.stream,
        ),
        cancelToken: _cancelToken,
      );
      
      // 处理流式响应 - 改进为支持完整的SSE格式
      String buffer = '';
      String? detectedConversationId;
      
      await for (final chunk in (response.data as ResponseBody).stream) {
        // 将字节数据转换为字符串并添加到缓冲区
        buffer += utf8.decode(chunk);
        
        // 按行处理缓冲区数据
        final lines = buffer.split('\n');
        // 保留最后一行（可能不完整）
        buffer = lines.removeLast();
        
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;
          
          // 处理Server-Sent Events格式
          if (trimmedLine.startsWith('data: ')) {
            final data = trimmedLine.substring(6);
            if (data == '[DONE]') break;
            
            try {
              final json = jsonDecode(data);
              
              // 获取会话ID（如果这是新创建的会话）
              if (detectedConversationId == null) {
                detectedConversationId = json['conversation_id'] as String?;
              }
              
              // 根据事件类型处理不同的响应
              final event = json['event'] as String?;
              
              if (event == 'message' || event == 'agent_message') {
                final answer = json['answer'] as String?;
                if (answer != null && answer.isNotEmpty) {
                  yield {
                    'content': answer,
                    'conversation_id': detectedConversationId ?? conversationId,
                    'event': event,
                  };
                }
              }
              // 可以在这里添加对其他事件类型的处理
              // 如 'tts_message', 'workflow_started' 等
              
            } catch (e) {
              print('解析流式数据错误: $e');
              // 继续处理下一行，不中断整个流
            }
          }
        }
      }
      
      // 处理缓冲区剩余数据
      if (buffer.trim().isNotEmpty && buffer.trim().startsWith('data: ')) {
        final data = buffer.trim().substring(6);
        if (data != '[DONE]') {
          try {
            final json = jsonDecode(data);
            
            // 获取会话ID（如果这是新创建的会话）
            if (detectedConversationId == null) {
              detectedConversationId = json['conversation_id'] as String?;
            }
            
            final event = json['event'] as String?;
            if (event == 'message' || event == 'agent_message') {
              final answer = json['answer'] as String?;
              if (answer != null && answer.isNotEmpty) {
                yield {
                  'content': answer,
                  'conversation_id': detectedConversationId ?? conversationId,
                  'event': event,
                };
              }
            }
          } catch (e) {
            print('解析缓冲区剩余数据错误: $e');
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        print('用户取消了请求');
      } else {
        print('网络请求错误: ${e.message}');
        throw Exception('发送消息失败: ${e.message}');
      }
    } catch (e) {
      print('发送消息时出现未知错误: $e');
      throw Exception('发送消息失败: $e');
    }
  }
  
  // 发送消息并获取完整回复（非流式）
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String conversationId,
    required String userId,
  }) async {
    try {
      final response = await _dio.post(
        AppConstants.difychatPath,
        data: {
          'inputs': {},
          'query': message,
          'response_mode': 'blocking',
          'conversation_id': conversationId, // 总是传递字符串，空时为 ""
          'user': userId,
        },
      );
      
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      print('发送消息失败: ${e.message}');
      throw Exception('发送消息失败: ${e.message}');
    }
  }
  
  // 停止生成
  void stopGeneration() {
    _cancelToken?.cancel('用户停止生成');
    _cancelToken = null;
  }
  
  // 获取TTS音频（改进版本）
  Future<String> getTTSAudio(String text) async {
    try {
      final response = await _dio.post(
        AppConstants.difyTtsPath,
        data: {
          'text': text,
          'user': 'default_user',
        },
        options: Options(
          responseType: ResponseType.bytes, // 期望二进制数据
        ),
      );
      
      // 检查是否是音频数据
      if (response.data is List<int>) {
        // 将音频数据编码为Base64，用于后续处理
        final audioBase64 = base64Encode(response.data);
        return 'data:audio/mp3;base64,$audioBase64';
      }
      
      // 如果不是二进制数据，尝试作为JSON解析
      if (response.data is String || response.data is Map) {
        final responseData = response.data is String 
            ? jsonDecode(response.data) 
            : response.data;
            
        print('TTS响应数据结构: $responseData');
        
        if (responseData is Map<String, dynamic>) {
          // 尝试常见的字段名
          final audioUrl = responseData['audio_url'] as String? ??
                          responseData['url'] as String? ??
                          responseData['data'] as String? ??
                          responseData['audio'] as String?;
          
          if (audioUrl != null) {
            return audioUrl;
          }
        }
      }
      
      throw Exception('TTS响应格式不符合预期，状态码: ${response.statusCode}');
      
    } on DioException catch (e) {
      print('获取TTS音频失败: ${e.message}');
      throw Exception('获取TTS音频失败: ${e.message}');
    }
  }
  
  // 流式TTS音频获取（参考文档的实现）
  Stream<Uint8List> streamTextToAudio({
    required String text,
    required String messageId,
    String voice = 'default',
  }) async* {
    try {
      final response = await _dio.post(
        AppConstants.difyTtsPath,
        data: {
          'message_id': messageId,
          'streaming': true,
          'voice': voice,
          'text': text,
        },
        options: Options(
          responseType: ResponseType.stream,
        ),
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final responseStream = response.data.stream as Stream<List<int>>;
        await for (final chunk in responseStream) {
          yield Uint8List.fromList(chunk);
        }
      }
    } on DioException catch (e) {
      print('流式TTS获取失败: ${e.message}');
      throw Exception('流式TTS获取失败: ${e.message}');
    }
  }
  
  // 获取TTS音频并返回Base64编码的音频数据流
  Stream<String> getTTSAudioStream({
    required String text,
    required String messageId,
    String voice = 'default',
  }) async* {
    try {
      final audioStream = streamTextToAudio(
        text: text,
        messageId: messageId,
        voice: voice,
      );
      
      await for (final audioChunk in audioStream) {
        if (audioChunk.isNotEmpty) {
          // 将音频字节数据编码为Base64
          final base64Audio = base64Encode(audioChunk);
          yield base64Audio;
        }
      }
    } catch (e) {
      print('TTS音频流处理失败: $e');
      throw Exception('TTS音频流处理失败: $e');
    }
  }

  // 获取会话列表
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      print('🚀 请求会话列表: GET /api/dify/conversations');
      
      final response = await _dio.get(
        '/api/dify/conversations',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('📤 请求头: ${response.requestOptions.headers}');
      print('✅ 会话列表响应: ${response.data}');
      print('📊 状态码: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // 修正：API返回的结构是 {data: {data: [...]}}，需要先获取外层data，再获取内层data
        final outerData = responseData['data'] as Map<String, dynamic>?;
        if (outerData != null) {
          final conversations = outerData['data'] as List?;
          
          if (conversations != null) {
            print('📋 获取到 ${conversations.length} 个会话');
            return conversations.cast<Map<String, dynamic>>();
          }
        }
      }
      
      print('⚠️ 会话列表响应格式异常');
      return [];
    } on DioException catch (e) {
      print('❌ 获取会话列表失败: ${e.message}');
      print('📍 请求URL: ${e.requestOptions.uri}');
      if (e.response != null) {
        print('📦 错误响应体: ${e.response?.data}');
        print('📊 错误状态码: ${e.response?.statusCode}');
      }
      throw Exception('获取会话列表失败: ${e.message}');
    }
  }

  // 删除会话
  Future<bool> deleteConversation(String conversationId) async {
    try {
      print('🚀 删除会话请求: DELETE /api/dify/conversations/$conversationId');
      
      final response = await _dio.delete(
        '/api/dify/conversations/$conversationId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ 删除会话响应: ${response.data}');
      print('📊 状态码: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['success'] == true;
      }
      
      return false;
    } on DioException catch (e) {
      print('❌ 删除会话失败: ${e.message}');
      print('📍 请求URL: ${e.requestOptions.uri}');
      if (e.response != null) {
        print('📦 错误响应体: ${e.response?.data}');
        print('📊 错误状态码: ${e.response?.statusCode}');
      }
      throw Exception('删除会话失败: ${e.message}');
    }
  }

  // 重命名会话
  Future<bool> renameConversation(String conversationId, String name) async {
    try {
      print('🚀 重命名会话请求: POST /api/dify/conversations/$conversationId/name');
      print('📦 请求体: {"name": "$name"}');
      
      final response = await _dio.post(
        '/api/dify/conversations/$conversationId/name',
        data: {
          'name': name,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ 重命名会话响应: ${response.data}');
      print('📊 状态码: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['success'] == true;
      }
      
      return false;
    } on DioException catch (e) {
      print('❌ 重命名会话失败: ${e.message}');
      print('📍 请求URL: ${e.requestOptions.uri}');
      if (e.response != null) {
        print('📦 错误响应体: ${e.response?.data}');
        print('📊 错误状态码: ${e.response?.statusCode}');
      }
      throw Exception('重命名会话失败: ${e.message}');
    }
  }

  // 获取会话消息
  Future<List<Map<String, dynamic>>> getConversationMessages(String conversationId) async {
    try {
      print('🚀 获取会话消息请求: GET /api/dify/conversations/$conversationId/messages');
      
      final response = await _dio.get(
        '/api/dify/conversations/$conversationId/messages',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ 会话消息响应: ${response.data}');
      print('📊 状态码: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // 修正：API返回的结构是 {data: {data: [...]}}，需要先获取外层data，再获取内层data
        final outerData = responseData['data'] as Map<String, dynamic>?;
        if (outerData != null) {
          final rawMessages = outerData['data'] as List?;
          
          if (rawMessages != null && rawMessages.isNotEmpty) {
            print('📋 获取到 ${rawMessages.length} 条原始消息记录');
            
            // 将API返回的消息记录转换为消息列表
            // 每条记录包含query和answer，需要转换为两条消息
            final List<Map<String, dynamic>> messages = [];
            
            for (final record in rawMessages) {
              final recordMap = record as Map<String, dynamic>;
              final createdAt = recordMap['created_at'] as int?;
              final conversationId = recordMap['conversation_id'] as String?;
              final messageId = recordMap['id'] as String?;
              
              // 用户消息（query）
              final query = recordMap['query'] as String?;
              if (query != null && query.isNotEmpty) {
                messages.add({
                  'id': '${messageId}_user',
                  'content': query,
                  'role': 'user',
                  'created_at': createdAt,
                  'conversation_id': conversationId,
                });
              }
              
              // AI回复（answer）
              final answer = recordMap['answer'] as String?;
              if (answer != null && answer.isNotEmpty) {
                messages.add({
                  'id': '${messageId}_assistant',
                  'content': answer,
                  'role': 'assistant',
                  'created_at': createdAt,
                  'conversation_id': conversationId,
                });
              }
            }
            
            print('📋 转换后得到 ${messages.length} 条消息');
            return messages;
          }
        }
      }
      
      print('⚠️ 会话消息响应格式异常');
      return [];
    } on DioException catch (e) {
      print('❌ 获取会话消息失败: ${e.message}');
      print('📍 请求URL: ${e.requestOptions.uri}');
      if (e.response != null) {
        print('📦 错误响应体: ${e.response?.data}');
        print('📊 错误状态码: ${e.response?.statusCode}');
      }
      throw Exception('获取会话消息失败: ${e.message}');
    }
  }
} 