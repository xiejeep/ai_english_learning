import 'package:flutter/foundation.dart';

/// TTS服务专用的日志工具类
class TTSLogger {
  static const String _tag = '[PlaylistTTS]';
  
  /// 信息日志
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ $_tag $message');
    }
  }
  
  /// 成功日志
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ $_tag $message');
    }
  }
  
  /// 警告日志
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ $_tag $message');
    }
  }
  
  /// 错误日志
  static void error(String message) {
    if (kDebugMode) {
      debugPrint('❌ $_tag $message');
    }
  }
  
  /// 调试日志
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🐛 $_tag $message');
    }
  }
  
  /// 播放相关日志
  static void playback(String message) {
    if (kDebugMode) {
      debugPrint('🎵 $_tag $message');
    }
  }
  
  /// 缓存相关日志
  static void cache(String message) {
    if (kDebugMode) {
      debugPrint('💾 $_tag $message');
    }
  }
  
  /// 清理相关日志
  static void cleanup(String message) {
    if (kDebugMode) {
      debugPrint('🧹 $_tag $message');
    }
  }
  
  /// 处理相关日志
  static void process(String message) {
    if (kDebugMode) {
      debugPrint('📦 $_tag $message');
    }
  }
  
  /// 搜索相关日志
  static void search(String message) {
    if (kDebugMode) {
      debugPrint('🔍 $_tag $message');
    }
  }
  
  /// 统计相关日志
  static void stats(String message) {
    if (kDebugMode) {
      debugPrint('📊 $_tag $message');
    }
  }
  
  /// 配置相关日志
  static void config(String message) {
    if (kDebugMode) {
      debugPrint('🔧 $_tag $message');
    }
  }
}