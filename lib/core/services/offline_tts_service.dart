import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// 离线TTS服务
/// 使用flutter_tts提供本地文本转语音功能
class OfflineTTSService {
  static OfflineTTSService? _instance;
  static OfflineTTSService get instance => _instance ??= OfflineTTSService._();
  
  OfflineTTSService._();
  
  FlutterTts? _flutterTts;
  bool _isInitialized = false;
  bool _isPlaying = false;
  
  // TTS状态回调
  Function()? _onStart;
  Function()? _onComplete;
  Function(String)? _onError;
  
  /// 初始化TTS服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _flutterTts = FlutterTts();
      
      // 设置TTS参数
      await _flutterTts!.setLanguage("en-US"); // 默认英语
      await _flutterTts!.setSpeechRate(0.5); // 语速
      await _flutterTts!.setVolume(1.0); // 音量
      await _flutterTts!.setPitch(1.0); // 音调
      
      // 设置回调
      _flutterTts!.setStartHandler(() {
        _isPlaying = true;
        _onStart?.call();
        print('🔊 TTS开始播放');
      });
      
      _flutterTts!.setCompletionHandler(() {
        _isPlaying = false;
        _onComplete?.call();
        print('✅ TTS播放完成');
      });
      
      _flutterTts!.setErrorHandler((msg) {
        _isPlaying = false;
        _onError?.call(msg);
        print('❌ TTS播放错误: $msg');
      });
      
      _flutterTts!.setCancelHandler(() {
        _isPlaying = false;
        _onComplete?.call();
        print('🛑 TTS播放取消');
      });
      
      // 在iOS上设置音频会话
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts!.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
      
      _isInitialized = true;
      print('✅ 离线TTS服务初始化完成');
    } catch (e) {
      print('❌ 离线TTS服务初始化失败: $e');
      rethrow;
    }
  }
  
  /// 设置状态回调
  void setCallbacks({
    Function()? onStart,
    Function()? onComplete,
    Function(String)? onError,
  }) {
    _onStart = onStart;
    _onComplete = onComplete;
    _onError = onError;
  }
  
  /// 播放文本
  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_flutterTts == null) {
      throw Exception('TTS服务未初始化');
    }
    
    try {
      // 如果正在播放，先停止
      if (_isPlaying) {
        await stop();
      }
      
      // 清理文本内容
      final cleanText = _cleanText(text);
      
      if (cleanText.isEmpty) {
        print('⚠️ 文本内容为空，跳过TTS播放');
        return;
      }
      
      print('🔊 开始TTS播放: ${cleanText.substring(0, cleanText.length.clamp(0, 50))}...');
      
      // 检测语言并设置
      await _setLanguageForText(cleanText);
      
      // 开始播放
      await _flutterTts!.speak(cleanText);
    } catch (e) {
      print('❌ TTS播放失败: $e');
      _onError?.call(e.toString());
      rethrow;
    }
  }
  
  /// 停止播放
  Future<void> stop() async {
    if (_flutterTts == null || !_isInitialized) return;
    
    try {
      await _flutterTts!.stop();
      _isPlaying = false;
      print('🛑 TTS播放已停止');
    } catch (e) {
      print('❌ 停止TTS播放失败: $e');
    }
  }
  
  /// 暂停播放
  Future<void> pause() async {
    if (_flutterTts == null || !_isInitialized) return;
    
    try {
      await _flutterTts!.pause();
      print('⏸️ TTS播放已暂停');
    } catch (e) {
      print('❌ 暂停TTS播放失败: $e');
    }
  }
  
  /// 检查是否正在播放
  bool get isPlaying => _isPlaying;
  
  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;
  
  /// 设置语速
  Future<void> setSpeechRate(double rate) async {
    if (_flutterTts == null) return;
    
    try {
      // 确保语速在合理范围内 (0.1 - 2.0)
      final validRate = rate.clamp(0.1, 2.0);
      await _flutterTts!.setSpeechRate(validRate);
      print('🎛️ TTS语速设置为: $validRate');
    } catch (e) {
      print('❌ 设置TTS语速失败: $e');
    }
  }
  
  /// 设置音量
  Future<void> setVolume(double volume) async {
    if (_flutterTts == null) return;
    
    try {
      // 确保音量在合理范围内 (0.0 - 1.0)
      final validVolume = volume.clamp(0.0, 1.0);
      await _flutterTts!.setVolume(validVolume);
      print('🔊 TTS音量设置为: $validVolume');
    } catch (e) {
      print('❌ 设置TTS音量失败: $e');
    }
  }
  
  /// 设置音调
  Future<void> setPitch(double pitch) async {
    if (_flutterTts == null) return;
    
    try {
      // 确保音调在合理范围内 (0.5 - 2.0)
      final validPitch = pitch.clamp(0.5, 2.0);
      await _flutterTts!.setPitch(validPitch);
      print('🎵 TTS音调设置为: $validPitch');
    } catch (e) {
      print('❌ 设置TTS音调失败: $e');
    }
  }
  
  /// 获取可用语言列表
  Future<List<String>> getLanguages() async {
    if (_flutterTts == null) return [];
    
    try {
      final languages = await _flutterTts!.getLanguages;
      return languages.cast<String>();
    } catch (e) {
      print('❌ 获取TTS语言列表失败: $e');
      return [];
    }
  }
  
  /// 清理文本内容
  String _cleanText(String text) {
    // 移除markdown格式
    String cleaned = text
        .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'$1') // 粗体
        .replaceAll(RegExp(r'\*(.*?)\*'), r'$1') // 斜体
        .replaceAll(RegExp(r'`(.*?)`'), r'$1') // 行内代码
        .replaceAll(RegExp(r'```.*?```', dotAll: true), '') // 代码块
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // 标题
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1') // 链接
        .replaceAll(RegExp(r'!\[([^\]]*)\]\([^\)]+\)'), r'$1') // 图片
        .replaceAll(RegExp(r'^>\s*', multiLine: true), '') // 引用
        .replaceAll(RegExp(r'^\s*[-*+]\s*', multiLine: true), '') // 列表
        .replaceAll(RegExp(r'^\s*\d+\.\s*', multiLine: true), ''); // 有序列表
    
    // 移除多余的空白字符
    cleaned = cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    return cleaned;
  }
  
  /// 根据文本内容设置合适的语言
  Future<void> _setLanguageForText(String text) async {
    if (_flutterTts == null) return;
    
    try {
      // 简单的语言检测逻辑
      final hasChineseChar = RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
      final hasEnglishChar = RegExp(r'[a-zA-Z]').hasMatch(text);
      
      String language = "en-US"; // 默认英语
      
      if (hasChineseChar && !hasEnglishChar) {
        // 纯中文
        language = "zh-CN";
      } else if (hasChineseChar && hasEnglishChar) {
        // 中英混合，优先中文
        language = "zh-CN";
      } else if (hasEnglishChar) {
        // 英文或英文为主
        language = "en-US";
      }
      
      await _flutterTts!.setLanguage(language);
      print('🌐 TTS语言设置为: $language');
    } catch (e) {
      print('❌ 设置TTS语言失败: $e');
      // 如果设置失败，保持默认语言
    }
  }
  
  /// 释放资源
  Future<void> dispose() async {
    try {
      await stop();
      _flutterTts = null;
      _isInitialized = false;
      _onStart = null;
      _onComplete = null;
      _onError = null;
      print('✅ 离线TTS服务已释放');
    } catch (e) {
      print('❌ 释放TTS服务失败: $e');
    }
  }
}