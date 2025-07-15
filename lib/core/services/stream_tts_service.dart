import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'playlist_tts_service.dart';

/// 流式TTS音频服务
/// 处理从流式响应中接收的Base64编码音频数据
/// 现在使用 PlaylistTTSService 作为底层播放引擎
class StreamTTSService {
  static StreamTTSService? _instance;
  static StreamTTSService get instance => _instance ??= StreamTTSService._();
  
  StreamTTSService._();
  
  // 播放列表服务
  final PlaylistTTSService _playlistService = PlaylistTTSService();
  
  // 基础状态
  bool _isInitialized = false;
  String? _currentMessageId;
  Directory? _cacheDir;
  
  // 回调函数
  VoidCallback? _onPlaybackStart;
  VoidCallback? _onPlaybackComplete;
  Function(String)? _onError;
  
  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 初始化播放列表服务
      await _playlistService.initialize();
      
      // 设置播放列表服务的回调
      _playlistService.setCallbacks(
        onPlaybackStarted: () {
          _onPlaybackStart?.call();
          print('🔊 [StreamTTS] 开始播放音频');
        },
        onPlaybackCompleted: () {
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
  
  /// 开始处理新的TTS消息
  void startTTSMessage(String messageId) {
    print('🎵 [StreamTTS] 开始处理TTS消息: $messageId');
    _currentMessageId = messageId;
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
        // 直接使用播放列表服务处理音频块
        _playlistService.processTTSChunk(messageId, base64Audio);
        print('📦 [StreamTTS] 音频块已发送到播放列表服务');
      }
    } catch (e) {
      print('❌ [StreamTTS] 处理音频块失败: $e');
      _onError?.call('处理音频块失败: $e');
    }
  }
  

  
  /// 完成TTS消息处理并播放音频
  Future<void> finishTTSMessage(String messageId) async {
    if (_currentMessageId != messageId) {
      print('⚠️ [StreamTTS] 完成消息ID不匹配，忽略');
      return;
    }
    
    try {
      print('✅ [StreamTTS] 完成TTS消息: $messageId');
      
      // 使用播放列表服务完成消息处理
      await _playlistService.finishTTSMessage(messageId);
      
    } catch (e) {
      print('❌ [StreamTTS] 完成TTS消息失败: $e');
      _onError?.call('完成TTS消息失败: $e');
    } finally {
      // 清理状态
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
      // 使用播放列表服务播放缓存音频
      await _playlistService.playMessageAudio(messageId);
    } catch (e) {
      print('❌ [StreamTTS] 播放缓存音频失败: $e');
      _onError?.call('播放失败: $e');
    }
  }
  
  /// 停止播放
  Future<void> stop() async {
    try {
      await _playlistService.stop();
      _cleanup();
      print('🛑 [StreamTTS] 播放已停止');
    } catch (e) {
      print('❌ [StreamTTS] 停止播放失败: $e');
    }
  }
  
  /// 检查是否正在播放
  bool get isPlaying => _playlistService.isPlaying;
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 获取播放状态流
  Stream<bool> get playingStream => _playlistService.playingStream;
  
  /// 获取播放进度流
  Stream<Duration> get positionStream => _playlistService.positionStream;
  
  /// 获取播放时长流
  Stream<Duration?> get durationStream => _playlistService.durationStream;
  
  /// 清理缓存
  Future<void> clearCache() async {
    try {
      await _playlistService.clearCache();
      
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
      await _playlistService.dispose();
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