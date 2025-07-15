import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:ai_english_learning/core/services/stream_tts_service.dart';
import 'package:ai_english_learning/core/services/message_id_mapping_service.dart';

/// TTS事件处理器
/// 负责处理所有TTS相关的事件，提供统一的事件处理接口
class TTSEventHandler {
  final Function(bool isLoading, bool isPlaying)? onStateUpdate;
  final VoidCallback? onUserProfileRefresh;

  TTSEventHandler({
    this.onStateUpdate,
    this.onUserProfileRefresh,
  });

  /// 初始化TTS事件处理器
  Future<void> initialize() async {
    try {
      print('🚀 [TTS Event] 正在初始化流式TTS服务...');
      await StreamTTSService.instance.initialize();
      
      // 设置TTS回调
      StreamTTSService.instance.setCallbacks(
        onStart: () {
          onStateUpdate?.call(false, true);
          print('🔍 [TTS Event] 流式TTS开始播放，isTTSPlaying=true');
          
          // TTS开始播放时刷新用户资料（表示功能使用）
          onUserProfileRefresh?.call();
        },
        onComplete: () {
          onStateUpdate?.call(false, false);
          print('🔍 [TTS Event] 流式TTS播放完成，isTTSPlaying=false');
        },
        onError: (error) {
          onStateUpdate?.call(false, false);
          print('❌ [TTS Event] 流式TTS播放错误: $error');
        },
      );
      
      print('✅ [TTS Event] 流式TTS服务初始化完成');
    } catch (e) {
      print('❌ [TTS Event] 流式TTS服务初始化失败: $e');
    }
  }

  /// 处理TTS消息开始事件
  void handleTTSStart(String serverMessageId, MessageIdMappingService mappingService) {
    try {
      final localMessageId = mappingService.getLocalId(serverMessageId);
      if (localMessageId != null) {
        print('🎬 [TTS Event] 开始处理TTS消息: $serverMessageId -> $localMessageId');
        StreamTTSService.instance.startTTSMessage(localMessageId);
      } else {
        print('⚠️ [TTS Event] 未找到本地消息ID映射: $serverMessageId');
      }
    } catch (e) {
      print('❌ [TTS Event] 处理TTS开始事件失败: $e');
    }
  }

  /// 处理TTS音频块事件
  void handleTTSChunk(String serverMessageId, String base64Audio, MessageIdMappingService mappingService) {
    try {
      final localMessageId = mappingService.getLocalId(serverMessageId);
      if (localMessageId != null) {
        print('🎵 [TTS Event] 接收音频块: $serverMessageId -> $localMessageId');
        
        // 确保TTS消息已开始（如果尚未开始，则先开始）
        if (!StreamTTSService.instance.isProcessingMessage(localMessageId)) {
          print('🎬 [TTS Event] 自动开始TTS消息处理: $localMessageId');
          StreamTTSService.instance.startTTSMessage(localMessageId);
        }
        
        StreamTTSService.instance.processTTSChunk(localMessageId, base64Audio);
      } else {
        print('⚠️ [TTS Event] 消息ID不匹配，忽略音频块: $serverMessageId');
      }
    } catch (e) {
      print('❌ [TTS Event] 处理音频块失败: $e');
    }
  }

  /// 处理TTS消息结束事件
  Future<void> handleTTSMessageEnd(String serverMessageId, MessageIdMappingService mappingService) async {
    try {
      final localMessageId = mappingService.getLocalId(serverMessageId);
      if (localMessageId != null) {
        print('🏁 [TTS Event] 处理TTS消息结束: $serverMessageId -> $localMessageId');
        await StreamTTSService.instance.finishTTSMessage(localMessageId);
      } else {
        print('⚠️ [TTS Event] 未找到本地消息ID映射: $serverMessageId');
      }
    } catch (e) {
      print('❌ [TTS Event] 处理TTS结束事件失败: $e');
    }
  }

  /// 停止TTS播放
  void stopTTS() {
    try {
      print('⏹️ [TTS Event] 停止TTS播放');
      StreamTTSService.instance.stop();
    } catch (e) {
      print('❌ [TTS Event] 停止TTS失败: $e');
    }
  }

  /// 播放指定消息的音频
  Future<void> playMessageAudio(String messageId) async {
    try {
      print('▶️ [TTS Event] 播放消息音频: $messageId');
      await StreamTTSService.instance.playMessageAudio(messageId);
    } catch (e) {
      print('❌ [TTS Event] 播放音频失败: $e');
    }
  }

  /// 释放资源
  void dispose() {
    try {
      print('🗑️ [TTS Event] 释放TTS事件处理器资源');
      StreamTTSService.instance.dispose();
    } catch (e) {
      print('❌ [TTS Event] 释放资源失败: $e');
    }
  }
}