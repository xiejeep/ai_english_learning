import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../../features/chat/data/datasources/chat_remote_datasource.dart';

/// 简化的TTS服务
/// 用于处理音频块的接收、合并和播放
class SimpleTTSService {
  static SimpleTTSService? _instance;
  static SimpleTTSService get instance => _instance ??= SimpleTTSService._();

  SimpleTTSService._();

  /// ChatRemoteDataSource 实例，用于重新获取音频
  ChatRemoteDataSource? _chatRemoteDataSource;

  // 播放器
  AudioPlayer? _player;

  // 音频块缓存
  final Map<String, List<Uint8List>> _audioChunks = {};
  final Map<String, String> _messageTexts = {};

  // 状态
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentMessageId;

  // 回调函数
  VoidCallback? _onPlaybackStart;
  VoidCallback? _onPlaybackComplete;
  Function(String)? _onError;

  // 流控制器
  StreamSubscription<PlayerState>? _playerStateSubscription;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _player = AudioPlayer();

      // 监听播放状态变化
      _playerStateSubscription = _player!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _onPlaybackComplete?.call();
          print('✅ [SimpleTTS] 音频播放完成');
        } else if (state.playing && !_isPlaying) {
          _isPlaying = true;
          _onPlaybackStart?.call();
          print('🔊 [SimpleTTS] 开始播放音频');
        }
      });

      _isInitialized = true;
      print('✅ [SimpleTTS] 服务初始化完成');
    } catch (e) {
      print('❌ [SimpleTTS] 初始化失败: $e');
      _onError?.call('初始化失败: $e');
      rethrow;
    }
  }

  /// 设置回调函数
  void setCallbacks({
    VoidCallback? onStart,
    VoidCallback? onComplete,
    Function(String)? onError,
  }) {
    _onPlaybackStart = onStart;
    _onPlaybackComplete = onComplete;
    _onError = onError;
  }

  /// 设置消息文本
  void setMessageText(String messageId, String messageText) {
    _messageTexts[messageId] = messageText;
    print('📝 [SimpleTTS] 设置消息文本: $messageId (${messageText.length} 字符)');
  }

  /// 开始处理新的TTS消息
  void startTTSMessage(String messageId) {
    print('🎵 [SimpleTTS] 开始处理TTS消息: $messageId');
    _currentMessageId = messageId;
    _audioChunks[messageId] = [];
  }

  /// 检查是否正在处理指定的消息ID
  bool isProcessingMessage(String messageId) {
    return _currentMessageId == messageId;
  }

  /// 处理TTS音频块（仅缓存，不播放）
  void processTTSChunk(String messageId, String base64Audio) {
    if (_currentMessageId != messageId) {
      print('⚠️ [SimpleTTS] 消息ID不匹配，忽略音频块');
      return;
    }

    try {
      if (base64Audio.isNotEmpty) {
        final audioData = base64Decode(base64Audio);
        _audioChunks[messageId]?.add(audioData);
        print('📦 [SimpleTTS] 缓存音频块: ${_audioChunks[messageId]?.length ?? 0}');
      }
    } catch (e) {
      print('❌ [SimpleTTS] 处理音频块失败: $e');
      _onError?.call('处理音频块失败: $e');
    }
  }

  /// 完成TTS消息处理并播放合并后的音频
  Future<void> finishTTSMessage(String messageId) async {
    print('🏁 [SimpleTTS] 完成TTS消息: $messageId');

    if (_currentMessageId != messageId) {
      print('⚠️ [SimpleTTS] 消息ID不匹配，忽略: 期望=$_currentMessageId, 实际=$messageId');
      return;
    }

    try {
      final chunks = _audioChunks[messageId];
      if (chunks == null || chunks.isEmpty) {
        print('⚠️ [SimpleTTS] 没有音频块可播放: $messageId');
        return;
      }

      print('🔄 [SimpleTTS] 合并 ${chunks.length} 个音频块');

      // 合并所有音频块
      final mergedAudio = _mergeAudioChunks(chunks);

      // 保存合并后的音频文件
      final audioFile = await _saveAudioFile(messageId, mergedAudio);

      // 停止当前播放
      if (_isPlaying) {
        await stop();
      }

      // 播放合并后的音频
      await _player!.setAudioSource(AudioSource.file(audioFile.path));
      await _player!.play();

      print('▶️ [SimpleTTS] 开始播放合并后的音频');

      // 缓存音频文件（如果有消息文本）
      final messageText = _messageTexts[messageId];
      if (messageText != null) {
        await _cacheAudioFile(messageText, audioFile);
      }
    } catch (e, stackTrace) {
      print('❌ [SimpleTTS] 完成TTS消息失败: $e');
      print('📍 [SimpleTTS] 错误堆栈: $stackTrace');
      _onError?.call('完成TTS消息失败: $e');
    } finally {
      // 清理状态
      _audioChunks.remove(messageId);
      _messageTexts.remove(messageId);
      _currentMessageId = null;
    }
  }

  /// 合并音频块
  Uint8List _mergeAudioChunks(List<Uint8List> chunks) {
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final merged = Uint8List(totalLength);

    int offset = 0;
    for (final chunk in chunks) {
      merged.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    return merged;
  }

  /// 保存音频文件
  Future<File> _saveAudioFile(String messageId, Uint8List audioData) async {
    final tempDir = await getTemporaryDirectory();
    final audioDir = Directory('${tempDir.path}/simple_tts');
    await audioDir.create(recursive: true);

    final audioFile = File('${audioDir.path}/$messageId.wav');
    await audioFile.writeAsBytes(audioData);

    return audioFile;
  }

  /// 缓存音频文件
  Future<void> _cacheAudioFile(String messageText, File audioFile) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final hash = _generateHash(messageText);
      final cachedFile = File('${cacheDir.path}/$hash.wav');

      await audioFile.copy(cachedFile.path);
      print('💾 [SimpleTTS] 音频已缓存: ${cachedFile.path}');
    } catch (e) {
      print('❌ [SimpleTTS] 缓存音频失败: $e');
    }
  }

  /// 设置 ChatRemoteDataSource 实例
  void setChatRemoteDataSource(ChatRemoteDataSource dataSource) {
    _chatRemoteDataSource = dataSource;
  }

  /// 播放缓存的音频，如果缓存不存在则重新获取
  Future<void> playMessageAudio(String messageText, {String? appId}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final cacheDir = await _getCacheDirectory();
      final hash = _generateHash(messageText);
      final cachedFile = File('${cacheDir.path}/$hash.wav');

      if (await cachedFile.exists()) {
        print('✅ [SimpleTTS] 播放缓存音频');

        // 停止当前播放
        if (_isPlaying) {
          await stop();
        }

        await _player!.setAudioSource(AudioSource.file(cachedFile.path));
        await _player!.play();
      } else {
        print('⚠️ [SimpleTTS] 缓存音频不存在，尝试重新获取');
        await _fetchAndPlayAudio(messageText, appId: appId);
      }
    } catch (e) {
      print('❌ [SimpleTTS] 播放缓存音频失败: $e');
      _onError?.call('播放失败: $e');
    }
  }

  /// 重新获取并播放音频
  Future<void> _fetchAndPlayAudio(String messageText, {String? appId}) async {
    if (_chatRemoteDataSource == null) {
      print('❌ [SimpleTTS] ChatRemoteDataSource 未设置，无法重新获取音频');
      _onError?.call('无法重新获取音频：服务未配置');
      return;
    }

    try {
      print(
        '🔄 [SimpleTTS] 开始重新获取音频: ${messageText.substring(0, messageText.length > 50 ? 50 : messageText.length)}...',
      );
      print('🔍 [SimpleTTS] 使用appId: $appId');

      // 调用 getTTSAudio 重新获取音频，传递appId参数
      final audioFilePath = await _chatRemoteDataSource!.getTTSAudio(
        messageText,
        appId: appId,
      );
      final audioFile = File(audioFilePath);

      if (await audioFile.exists()) {
        print('✅ [SimpleTTS] 音频重新获取成功');

        // 缓存新获取的音频
        await _cacheAudioFile(messageText, audioFile);

        // 停止当前播放
        if (_isPlaying) {
          await stop();
        }

        // 播放新获取的音频
        await _player!.setAudioSource(AudioSource.file(audioFile.path));
        await _player!.play();

        print('▶️ [SimpleTTS] 开始播放重新获取的音频');
      } else {
        print('❌ [SimpleTTS] 重新获取音频失败：文件不存在');
        _onError?.call('重新获取音频失败');
      }
    } catch (e) {
      print('❌ [SimpleTTS] 重新获取音频失败: $e');
      _onError?.call('重新获取音频失败: $e');
    }
  }

  /// 停止播放
  Future<void> stop() async {
    try {
      if (_player != null) {
        await _player!.stop();
        _isPlaying = false;
      }
      print('🛑 [SimpleTTS] 播放已停止');
    } catch (e) {
      print('❌ [SimpleTTS] 停止播放失败: $e');
    }
  }

  /// 获取缓存目录
  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/simple_tts_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  /// 生成消息文本的哈希值
  String _generateHash(String text) {
    final bytes = utf8.encode(text);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 清理缓存
  Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = await cacheDir.list().toList();

      for (final entity in files) {
        if (entity is File) {
          await entity.delete();
        }
      }

      print('🗑️ [SimpleTTS] 缓存已清理');
    } catch (e) {
      print('❌ [SimpleTTS] 清理缓存失败: $e');
    }
  }

  /// 获取播放状态
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;

  /// 获取播放状态流
  Stream<bool> get playingStream =>
      _player?.playingStream ?? const Stream.empty();

  /// 获取播放进度流
  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream.empty();

  /// 获取播放时长流
  Stream<Duration?> get durationStream =>
      _player?.durationStream ?? const Stream.empty();

  /// 释放资源
  Future<void> dispose() async {
    try {
      await stop();
      await _playerStateSubscription?.cancel();
      await _player?.dispose();

      _audioChunks.clear();
      _messageTexts.clear();
      _isInitialized = false;
      _currentMessageId = null;

      _onPlaybackStart = null;
      _onPlaybackComplete = null;
      _onError = null;

      print('✅ [SimpleTTS] 服务已释放');
    } catch (e) {
      print('❌ [SimpleTTS] 释放服务失败: $e');
    }
  }
}
