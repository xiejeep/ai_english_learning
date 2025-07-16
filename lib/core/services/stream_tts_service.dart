import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'simple_tts_service.dart';
import '../../features/chat/data/datasources/chat_remote_datasource.dart';

/// 流式TTS音频服务
/// 处理从流式响应中接收的Base64编码音频数据
/// 现在使用 SimpleTTSService 作为底层播放引擎
class StreamTTSService {
  static StreamTTSService? _instance;
  static StreamTTSService get instance => _instance ??= StreamTTSService._();
  
  StreamTTSService._();
  
  // 简化TTS服务
  final SimpleTTSService _simpleTTSService = SimpleTTSService.instance;
  
  // 基础状态
  bool _isInitialized = false;
  String? _currentMessageId;
  Directory? _cacheDir;
  
  // 回调函数
  VoidCallback? _onPlaybackStart;
  VoidCallback? _onPlaybackComplete;
  Function(String)? _onError;
  
  /// 初始化服务
  Future<void> initialize({ChatRemoteDataSource? chatRemoteDataSource}) async {
    if (_isInitialized) return;
    
    try {
      // 初始化简化TTS服务
      await _simpleTTSService.initialize();
      
      // 设置 ChatRemoteDataSource（如果提供）
      if (chatRemoteDataSource != null) {
        _simpleTTSService.setChatRemoteDataSource(chatRemoteDataSource);
        print('✅ [StreamTTS] ChatRemoteDataSource 已设置');
      } else {
        // 尝试创建默认的 ChatRemoteDataSource 实例
        try {
          final defaultDataSource = ChatRemoteDataSource();
          _simpleTTSService.setChatRemoteDataSource(defaultDataSource);
          print('✅ [StreamTTS] 使用默认 ChatRemoteDataSource');
        } catch (e) {
          print('⚠️ [StreamTTS] 无法创建默认 ChatRemoteDataSource: $e');
        }
      }
      
      // 设置简化TTS服务的回调
      _simpleTTSService.setCallbacks(
        onStart: () {
          _onPlaybackStart?.call();
          print('🔊 [StreamTTS] 开始播放音频');
        },
        onComplete: () {
          _onPlaybackComplete?.call();
          print('✅ [StreamTTS] 音频播放完成');
        },
        onError: (error) {
          _onError?.call(error);
          print('❌ [StreamTTS] 播放错误: $error');
        },
      );
      
      // 初始化缓存目录（保持兼容性）
      await _initCacheDirectory();
      
      _isInitialized = true;
      print('✅ [StreamTTS] 流式TTS服务初始化完成');
    } catch (e) {
      print('❌ [StreamTTS] 服务初始化失败: $e');
      rethrow;
    }
  }
  
  /// 初始化缓存目录
  Future<void> _initCacheDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(appDir.path, 'stream_tts_cache'));
      
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      print('📁 [StreamTTS] 缓存目录已初始化: ${_cacheDir!.path}');
    } catch (e) {
      print('❌ [StreamTTS] 缓存目录初始化失败: $e');
      rethrow;
    }
  }
  
  /// 设置状态回调
  void setCallbacks({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(String)? onError,
  }) {
    _onPlaybackStart = onStart;
    _onPlaybackComplete = onComplete;
    _onError = onError;
  }
  
  /// 设置消息文本（用于缓存）
  void setMessageText(String messageId, String messageText) {
    print('📝 [StreamTTS] 设置消息文本: $messageId');
    print('📝 [StreamTTS] 消息文本长度: ${messageText.length}');
    print('📝 [StreamTTS] 消息文本预览: ${messageText.length > 50 ? '${messageText.substring(0, 50)}...' : messageText}');
    
    // 设置消息文本到简化TTS服务
    _simpleTTSService.setMessageText(messageId, messageText);
    print('✅ [StreamTTS] 消息文本已设置到简化TTS服务');
  }

  /// 开始处理新的TTS消息
  void startTTSMessage(String messageId) {
    print('🎵 [StreamTTS] 开始处理TTS消息: $messageId');
    _currentMessageId = messageId;
    
    // 同时启动简化TTS服务的消息处理
    _simpleTTSService.startTTSMessage(messageId);
    print('✅ [StreamTTS] 已启动SimpleTTSService消息处理: $messageId');
  }
  
  /// 检查是否正在处理指定的消息ID
  bool isProcessingMessage(String messageId) {
    return _currentMessageId == messageId;
  }
  
  /// 处理TTS音频块
  void processTTSChunk(String messageId, String base64Audio) {
    if (_currentMessageId != messageId) {
      print('⚠️ [StreamTTS] 消息ID不匹配，忽略音频块');
      return;
    }
    
    try {
      if (base64Audio.isNotEmpty) {
        // 直接使用简化TTS服务处理音频块
        _simpleTTSService.processTTSChunk(messageId, base64Audio);
        print('📦 [StreamTTS] 音频块已发送到简化TTS服务');
      }
    } catch (e) {
      print('❌ [StreamTTS] 处理音频块失败: $e');
      _onError?.call('处理音频块失败: $e');
    }
  }
  

  
  /// 完成TTS消息处理并播放音频
  Future<void> finishTTSMessage(String messageId) async {
    print('🏁 [StreamTTS] 接收到完成TTS消息请求: $messageId');
    print('🔍 [StreamTTS] 当前处理的消息ID: $_currentMessageId');
    
    if (_currentMessageId != messageId) {
      print('⚠️ [StreamTTS] 完成消息ID不匹配，忽略: 期望=$_currentMessageId, 实际=$messageId');
      return;
    }
    
    try {
      print('✅ [StreamTTS] 开始完成TTS消息: $messageId');
      
      // 使用简化TTS服务完成消息处理
      print('📞 [StreamTTS] 调用SimpleTTSService.finishTTSMessage');
      await _simpleTTSService.finishTTSMessage(messageId);
      print('✅ [StreamTTS] SimpleTTSService.finishTTSMessage 调用完成');
      
    } catch (e, stackTrace) {
      print('❌ [StreamTTS] 完成TTS消息失败: $e');
      print('📍 [StreamTTS] 错误堆栈: $stackTrace');
      _onError?.call('完成TTS消息失败: $e');
    } finally {
      // 清理状态
      print('🧹 [StreamTTS] 清理状态，重置当前消息ID');
      _currentMessageId = null;
    }
  }
  
  /// 清理状态
  void _cleanup() {
    _currentMessageId = null;
  }
  
  /// 直接播放缓存的音频（用于重播）
  Future<void> playMessageAudio(String messageId) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // 使用简化TTS服务播放缓存音频
      await _simpleTTSService.playMessageAudio(messageId);
    } catch (e) {
      print('❌ [StreamTTS] 播放缓存音频失败: $e');
      _onError?.call('播放失败: $e');
    }
  }
  
  /// 根据消息内容播放缓存音频（新方法）
  Future<void> playMessageAudioByContent(String messageContent, {String? appId}) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // 使用简化TTS服务播放缓存音频（传入消息内容和appId）
      await _simpleTTSService.playMessageAudio(messageContent, appId: appId);
    } catch (e) {
      print('❌ [StreamTTS] 播放缓存音频失败: $e');
      _onError?.call('播放失败: $e');
    }
  }
  
  /// 停止播放
  Future<void> stop() async {
    try {
      await _simpleTTSService.stop();
      _cleanup();
      print('🛑 [StreamTTS] 播放已停止');
    } catch (e) {
      print('❌ [StreamTTS] 停止播放失败: $e');
    }
  }
  
  /// 检查是否正在播放
  bool get isPlaying => _simpleTTSService.isPlaying;
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 获取播放状态流
  Stream<bool> get playingStream => _simpleTTSService.playingStream;
  
  /// 获取播放进度流
  Stream<Duration> get positionStream => _simpleTTSService.positionStream;
  
  /// 获取播放时长流
  Stream<Duration?> get durationStream => _simpleTTSService.durationStream;
  
  /// 清理缓存
  Future<void> clearCache() async {
    try {
      await _simpleTTSService.clearCache();
      
      // 清理本地缓存目录
      if (_cacheDir != null) {
        final files = await _cacheDir!.list().toList();
        
        for (final entity in files) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      
      print('🗑️ [StreamTTS] 缓存已清理');
    } catch (e) {
      print('❌ [StreamTTS] 清理缓存失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      await stop();
      await _simpleTTSService.dispose();
      _isInitialized = false;
      _cleanup();
      _onPlaybackStart = null;
      _onPlaybackComplete = null;
      _onError = null;
      print('✅ [StreamTTS] 服务已释放');
    } catch (e) {
      print('❌ [StreamTTS] 释放服务失败: $e');
    }
  }
}