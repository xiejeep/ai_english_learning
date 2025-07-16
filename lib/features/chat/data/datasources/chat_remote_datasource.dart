import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
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
    String? appId,
  }) async* {
    await for (final data in sendMessageStreamWithConversationIdAndType(
      message: message,
      conversationId: conversationId,
      type: null,
      appId: appId,
    )) {
      final content = data['content'] as String?;
      if (content != null && content.isNotEmpty) {
        yield content;
      }
    }
  }


  
  // 带类型参数的流式响应
  Stream<Map<String, dynamic>> sendMessageStreamWithConversationIdAndType({
    required String message,
    required String conversationId,
    String? type,
    String? appId,
  }) async* {
    try {
      _cancelToken = CancelToken();
      
      final Map<String, dynamic> requestData = {
        'inputs': (type != null && type.isNotEmpty) ? {'type': type} : {},
        'query': message,
        'response_mode': 'streaming',
        'conversation_id': conversationId, // 总是传递字符串，空时为 ""
      };
      
      if (appId != null && appId.isNotEmpty) {
        requestData['appId'] = appId;
      }
      
      final response = await _dio.post(
        AppConstants.difychatPath,
        data: requestData,
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
              detectedConversationId ??= json['conversation_id'] as String?;
              
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
              } else if (event == 'tts_message') {
                // 处理TTS音频块事件
                final messageId = json['message_id'] as String?;
                final audio = json['audio'] as String?;
                if (messageId != null) {
                  yield {
                    'event': 'tts_message',
                    'message_id': messageId,
                    'audio': audio ?? '',
                    'conversation_id': detectedConversationId ?? conversationId,
                  };
                }
              } else if (event == 'tts_message_end') {
                // 处理TTS消息结束事件
                final messageId = json['message_id'] as String?;
                if (messageId != null) {
                  yield {
                    'event': 'tts_message_end',
                    'message_id': messageId,
                    'conversation_id': detectedConversationId ?? conversationId,
                  };
                }
              } else if (event == 'message_end') {
                // 处理消息结束事件，获取message_id用于TTS
                final messageId = json['id'] as String?;
                if (messageId != null) {
                  yield {
                    'event': 'message_end',
                    'message_id': messageId,
                    'conversation_id': detectedConversationId ?? conversationId,
                  };
                }
              }
              
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
            detectedConversationId ??= json['conversation_id'] as String?;
            
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
        print('❌ 错误: ${e.message}');
        print('📍 请求: ${e.requestOptions.uri}');
        
        // 尝试从错误响应中提取message字段
        String errorMessage = e.message ?? '发送消息失败';
        
        if (e.response?.data != null) {
          try {
            String responseBody;
            if (e.response!.data is ResponseBody) {
               final responseBodyObj = e.response!.data as ResponseBody;
               final bytes = <int>[];
               await for (final chunk in responseBodyObj.stream) {
                 bytes.addAll(chunk);
               }
               responseBody = utf8.decode(bytes);
            } else if (e.response!.data is String) {
              responseBody = e.response!.data as String;
            } else if (e.response!.data is Map) {
              responseBody = jsonEncode(e.response!.data);
            } else {
              responseBody = e.response!.data.toString();
            }
            
            print('📦 错误响应体: $responseBody');
            
            if (responseBody.isNotEmpty && responseBody != 'null') {
              final errorData = jsonDecode(responseBody);
              if (errorData is Map<String, dynamic> && errorData.containsKey('message')) {
                errorMessage = errorData['message'] as String;
                print('💬 提取到错误消息: $errorMessage');
              }
            }
          } catch (parseError) {
            print('⚠️ 无法解析错误响应: $parseError');
          }
        }
        
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('发送消息时出现未知错误: $e');
      throw Exception('发送消息失败');
    }
  }
  
  
  // 停止生成
  void stopGeneration() {
    _cancelToken?.cancel('用户停止生成');
    _cancelToken = null;
  }
  
  // 获取TTS音频（直接接收二进制数据）
  Future<String> getTTSAudio(String text, {String? appId}) async {
    try {
      print('开始获取TTS音频: "${text.length > 50 ? "${text.substring(0, 50)}..." : text}"');
      
      final Map<String, dynamic> requestData = {
        'text': text,
        'user': 'default_user',
      };
      
      if (appId != null && appId.isNotEmpty) {
        requestData['appId'] = appId;
      }
      
      final response = await _dio.post(
        AppConstants.difyTtsPath,
        data: requestData,
        options: Options(
          responseType: ResponseType.bytes, // 直接接收二进制数据
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg, application/json',
          },
        ),
      );
      
      print('TTS响应状态码: ${response.statusCode}');
      
      // 接受200和201状态码作为成功响应
      if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
        // 检查响应类型
        final contentType = response.headers['content-type']?.first ?? '';
        print('响应内容类型: $contentType');
        
        if (contentType.contains('application/json')) {
          // 如果是JSON响应，说明可能包含错误信息
          Map<String, dynamic> responseData;
          
          // 处理不同类型的响应数据
          if (response.data is String) {
            final jsonString = response.data as String;
            responseData = jsonDecode(jsonString) as Map<String, dynamic>;
          } else if (response.data is List<int>) {
            final jsonString = utf8.decode(response.data as List<int>);
            responseData = jsonDecode(jsonString) as Map<String, dynamic>;
          } else {
            responseData = response.data as Map<String, dynamic>;
          }
          
          print('解析后的JSON响应: ${responseData.toString().substring(0, math.min(200, responseData.toString().length))}...');
          
          if (responseData.containsKey('error')) {
            throw Exception('TTS服务返回错误: ${responseData['error']}');
          }
          
          // 处理后端返回的Buffer格式数据
          final audioData = responseData['data'];
          if (audioData != null) {
            List<int> audioBytes;
            
            if (audioData is String) {
              // 如果是字符串，进行Base64解码
              print('音频数据为字符串格式，长度: ${audioData.length}');
              try {
                audioBytes = base64Decode(audioData);
                print('Base64解码成功，音频字节长度: ${audioBytes.length}');
              } catch (e) {
                print('Base64解码失败: $e');
                throw Exception('音频数据Base64解码失败: $e');
              }
            } else if (audioData is Map<String, dynamic> && audioData['type'] == 'Buffer') {
              // 如果是Buffer格式，直接提取data数组
              print('音频数据为Buffer格式');
              final dataList = audioData['data'] as List<dynamic>?;
              if (dataList != null) {
                audioBytes = dataList.cast<int>();
                print('Buffer数据提取成功，音频字节长度: ${audioBytes.length}');
              } else {
                throw Exception('Buffer格式数据中没有找到data数组');
              }
            } else {
              throw Exception('不支持的音频数据格式: ${audioData.runtimeType}');
            }
            
            // 验证音频文件头
            if (audioBytes.length >= 3) {
              final header = String.fromCharCodes(audioBytes.take(3));
              print('音频文件头: $header');
              
              if (header == 'ID3' || audioBytes[0] == 0xFF || audioBytes[0] == 0x52) {
                // ID3 (MP3), FF (MP3 frame), 52 (RIFF/WAV)
                print('检测到有效的音频文件格式');
              } else {
                print('音频文件头不匹配，前10个字节: ${audioBytes.take(10).toList()}');
                print('仍尝试保存音频文件');
              }
            }
            
            return await _saveAudioToTempFile(audioBytes);
          }
          
          throw Exception('JSON响应中没有找到音频数据');
        } else {
          // 直接是二进制音频数据
          final audioBytes = response.data as List<int>;
          print('接收到音频字节数据，长度: ${audioBytes.length}');
          
          // 检查音频文件头
          if (audioBytes.length >= 3) {
            final header = String.fromCharCodes(audioBytes.take(3));
            print('音频文件头: $header');
            
            if (header == 'ID3' || audioBytes[0] == 0xFF || audioBytes[0] == 0x52) {
              // ID3 (MP3), FF (MP3 frame), 52 (RIFF/WAV)
              print('检测到有效的音频文件格式');
              
              // 保存为临时文件并返回路径
              final tempFile = await _saveAudioToTempFile(audioBytes);
              print('音频已保存到临时文件: $tempFile');
              return tempFile;
            } else {
              print('音频文件头不匹配，前10个字节: ${audioBytes.take(10).toList()}');
            }
          }
          
          throw Exception('接收到的数据不是有效的音频文件格式');
        }
      }
      
      throw Exception('TTS请求失败，状态码: ${response.statusCode}');
      
    } on DioException catch (e) {
      print('获取TTS音频失败: ${e.message}');
      if (e.response != null) {
        print('错误响应状态: ${e.response?.statusCode}');
        print('错误响应数据: ${e.response?.data}');
      }
      
      // 尝试使用备用方法获取TTS
      try {
        print('尝试使用JSON格式获取TTS音频...');
        return await _getTTSAudioAsJson(text, appId: appId);
      } catch (jsonError) {
        print('JSON方法也失败: $jsonError');
        throw Exception('获取TTS音频失败: ${e.message}');
      }
    }
  }

  // 备用TTS获取方法：以JSON格式接收
  Future<String> _getTTSAudioAsJson(String text, {String? appId}) async {
    final Map<String, dynamic> requestData = {
      'text': text,
      'user': 'default_user',
    };
    
    if (appId != null && appId.isNotEmpty) {
      requestData['appId'] = appId;
    }
    
    final response = await _dio.post(
      AppConstants.difyTtsPath,
      data: requestData,
      options: Options(
        responseType: ResponseType.json,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    if ((response.statusCode == 200 || response.statusCode == 201) && response.data != null) {
      final responseData = response.data as Map<String, dynamic>;
      
      if (responseData.containsKey('error')) {
        throw Exception('TTS服务返回错误: ${responseData['error']}');
      }
      
      final audioDataString = responseData['data'] as String?;
      if (audioDataString == null || audioDataString.isEmpty) {
        throw Exception('TTS服务返回空音频数据');
      }
      
      print('JSON方法获取的音频数据长度: ${audioDataString.length}');
      
      // 直接进行Base64解码（后端现在返回Base64编码的音频）
      print('开始Base64解码音频数据');
      try {
        final audioBytes = base64Decode(audioDataString);
        print('Base64解码成功，音频数据大小: ${audioBytes.length} 字节');
        
        // 验证音频文件头
        if (audioBytes.length >= 3) {
          final header = String.fromCharCodes(audioBytes.take(3));
          print('音频文件头: $header');
          
          // 检查常见音频格式
          if (header == 'ID3' || audioBytes[0] == 0xFF || audioBytes[0] == 0x52) {
            print('检测到有效的音频格式');
          } else {
            print('警告: 未识别的音频格式，但仍尝试保存');
          }
        }
        
        return await _saveAudioToTempFile(audioBytes);
      } catch (e) {
        print('Base64解码失败: $e');
        throw Exception('Base64解码失败: $e');
      }
    }
    
    throw Exception('JSON方法TTS请求失败，状态码: ${response.statusCode}');
  }

  // 保存音频数据到临时文件
  Future<String> _saveAudioToTempFile(List<int> audioBytes) async {
    try {
      // 确保临时目录存在
      final tempDir = await getTemporaryDirectory();
      await tempDir.create(recursive: true);
      
      // 创建临时文件
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/tts_audio_$timestamp.mp3');
      
      // 写入音频数据并强制刷新
      await tempFile.writeAsBytes(audioBytes, flush: true);
      
      // 验证文件是否成功创建
      if (await tempFile.exists()) {
        final fileSize = await tempFile.length();
        print('音频文件已保存: ${tempFile.path}, 大小: $fileSize 字节');
        
        // 验证文件是否可读
        try {
          final testBytes = await tempFile.readAsBytes();
          if (testBytes.length != audioBytes.length) {
            throw Exception('文件保存验证失败：大小不匹配');
          }
          print('音频文件验证成功');
        } catch (e) {
          print('音频文件验证失败: $e');
          throw Exception('音频文件保存后无法验证');
        }
        
        return tempFile.path;
      } else {
        throw Exception('音频文件创建失败');
      }
    } catch (e) {
      print('保存音频临时文件失败: $e');
      rethrow;
    }
  }


  


  // 获取会话列表
  Future<List<Map<String, dynamic>>> getConversations({String? appId}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (appId != null && appId.isNotEmpty) {
        queryParams['appId'] = appId;
      }
      
      print('🚀 请求会话列表: GET ${AppConstants.difyConversationsPath}${queryParams.isNotEmpty ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}');
      
      final response = await _dio.get(
        AppConstants.difyConversationsPath,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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

  // 获取最新的会话（优化版本，只返回1条记录）
  Future<Map<String, dynamic>?> getLatestConversation({String? appId}) async {
    try {
      final Map<String, dynamic> queryParams = {'limit': 1};
      if (appId != null && appId.isNotEmpty) {
        queryParams['appId'] = appId;
      }
      
      print('🚀 请求最新会话: GET ${AppConstants.difyConversationsPath}?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}');
      
      final response = await _dio.get(
        AppConstants.difyConversationsPath,
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('📤 请求头: ${response.requestOptions.headers}');
      print('✅ 最新会话响应: ${response.data}');
      print('📊 状态码: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // 修正：API返回的结构是 {data: {data: [...]}}，需要先获取外层data，再获取内层data
        final outerData = responseData['data'] as Map<String, dynamic>?;
        if (outerData != null) {
          final conversations = outerData['data'] as List?;
          
          if (conversations != null && conversations.isNotEmpty) {
            final latestConversation = conversations.first as Map<String, dynamic>;
            print('📋 获取到最新会话: ${latestConversation['id']}');
            return latestConversation;
          }
        }
      }
      
      print('⚠️ 没有找到会话');
      return null;
    } on DioException catch (e) {
      print('❌ 获取最新会话失败: ${e.message}');
      print('📍 请求URL: ${e.requestOptions.uri}');
      if (e.response != null) {
        print('📦 错误响应体: ${e.response?.data}');
        print('📊 错误状态码: ${e.response?.statusCode}');
      }
      throw Exception('获取最新会话失败: ${e.message}');
    }
  }

  // 删除会话
  Future<bool> deleteConversation(String conversationId, {String? appId}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (appId != null && appId.isNotEmpty) {
        queryParams['appId'] = appId;
      }
      
      print('🚀 删除会话请求: DELETE ${AppConstants.difyConversationsPath}/$conversationId${queryParams.isNotEmpty ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}');
      
      final response = await _dio.delete(
        '${AppConstants.difyConversationsPath}/$conversationId',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
  Future<bool> renameConversation(String conversationId, String name, {String? appId}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (appId != null && appId.isNotEmpty) {
        queryParams['appId'] = appId;
      }
      
      print('🚀 重命名会话请求: POST ${AppConstants.difyConversationsPath}/$conversationId/name${queryParams.isNotEmpty ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}');
      print('📦 请求体: {"name": "$name"}');
      
      final response = await _dio.post(
        '${AppConstants.difyConversationsPath}/$conversationId/name',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
  Future<List<Map<String, dynamic>>> getConversationMessages(String conversationId, {String? appId}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (appId != null && appId.isNotEmpty) {
        queryParams['appId'] = appId;
      }
      
      print('🚀 获取会话消息请求: GET ${AppConstants.difyConversationsPath}/$conversationId/messages${queryParams.isNotEmpty ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}');
      
      final response = await _dio.get(
        '${AppConstants.difyConversationsPath}/$conversationId/messages',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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

  // 获取会话消息（带分页参数）
  Future<Map<String, dynamic>> getConversationMessagesWithPagination(
    String conversationId, {
    int? limit,
    String? firstId,
    String? appId,
  }) async {
    try {
      print('🔍 [DEBUG] DataSource收到分页请求: conversationId=$conversationId, appId=$appId');
      print('🔍 [DEBUG] 参数详情: limit=$limit, firstId=$firstId');
      print('🔍 [DEBUG] firstId检查: isNull=${firstId == null}, isEmpty=${firstId?.isEmpty ?? true}, value="$firstId"');
      
      final queryParams = <String, dynamic>{};
      if (limit != null) {
        queryParams['limit'] = limit;
        print('🔍 [DEBUG] 添加limit参数: $limit');
      }
      if (firstId != null) {
        queryParams['first_id'] = firstId;
        print('🔍 [DEBUG] 添加first_id参数: $firstId');
      } else {
        print('🔍 [DEBUG] firstId为空，不添加first_id参数: firstId=$firstId');
      }
      if (appId != null && appId.isNotEmpty) {
        queryParams['appId'] = appId;
        print('🔍 [DEBUG] 添加appId参数: $appId');
      }
      
      print('🔍 [DEBUG] 最终查询参数: $queryParams');
      print('🚀 获取会话消息请求: GET ${AppConstants.difyConversationsPath}/$conversationId/messages${queryParams.isNotEmpty ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}');
      
      final response = await _dio.get(
        '${AppConstants.difyConversationsPath}/$conversationId/messages',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
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
          final hasMore = outerData['has_more'] as bool? ?? false;
          
          print('📊 API返回分页信息: has_more=$hasMore, 原始消息数=${rawMessages?.length ?? 0}');
          
          final List<Map<String, dynamic>> messages = [];
          
          if (rawMessages != null && rawMessages.isNotEmpty) {
            print('📋 获取到 ${rawMessages.length} 条原始消息记录');
            
            // 将API返回的消息记录转换为消息列表
            // 每条记录包含query和answer，需要转换为两条消息
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
          }
          
          return {
            'messages': messages,
            'has_more': hasMore,
          };
        }
      }
      
      print('⚠️ 会话消息响应格式异常');
      return {
        'messages': <Map<String, dynamic>>[],
        'has_more': false,
      };
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

  // 获取token使用历史
  Future<List<Map<String, dynamic>>> getTokenUsageHistory({String? appId}) async {
    try {
      final Map<String, dynamic> queryParams = {};
      if (appId != null && appId.isNotEmpty) {
        queryParams['appId'] = appId;
      }
      
      print('🚀 获取token使用历史请求: GET ${AppConstants.difyTokenUsageHistoryPath}${queryParams.isNotEmpty ? '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}' : ''}');
      
      final response = await _dio.get(
        AppConstants.difyTokenUsageHistoryPath,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );
      
      print('✅ token使用历史响应: ${response.data}');
      print('📊 状态码: ${response.statusCode}');
      
      if (response.statusCode == 200 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        
        // API返回的数据结构是 {records: [...]}
        final records = responseData['records'] as List?;
        
        if (records != null) {
          print('📋 获取到 ${records.length} 条token使用记录');
          return records.cast<Map<String, dynamic>>();
        }
      }
      
      print('⚠️ token使用历史响应格式异常');
      return [];
    } on DioException catch (e) {
      print('❌ 获取token使用历史失败: ${e.message}');
      print('📍 请求URL: ${e.requestOptions.uri}');
      if (e.response != null) {
        print('📦 错误响应体: ${e.response?.data}');
        print('📊 错误状态码: ${e.response?.statusCode}');
      }
      throw Exception('获取token使用历史失败: ${e.message}');
    }
  }
}