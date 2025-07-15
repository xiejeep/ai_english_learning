import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// 基于 just_audio 的播放列表 TTS 服务
/// 实现类似 HLS 的分段音频播放机制
class PlaylistTTSService {
  static final PlaylistTTSService _instance = PlaylistTTSService._internal();
  factory PlaylistTTSService() => _instance;
  PlaylistTTSService._internal();

  // 核心播放器组件
  AudioPlayer? _player;
  ConcatenatingAudioSource? _playlist;
  
  // 音频块管理
  final List<File> _audioChunkFiles = [];
  String? _currentMessageId;
  int _chunkCounter = 0;
  bool _isInitialized = false;
  bool _isPlaying = false;
  
  // 回调函数
  VoidCallback? _onPlaybackStarted;
  VoidCallback? _onPlaybackCompleted;
  Function(String)? _onError;
  
  // 流控制器
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  /// 初始化播放器
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      _player = AudioPlayer();
      _playlist = ConcatenatingAudioSource(
        useLazyPreparation: true, // 懒加载优化性能
        children: [],
      );
      
      await _player!.setAudioSource(_playlist!);
      
      // 监听播放状态变化
      _playerStateSubscription = _player!.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _onPlaybackCompleted?.call();
        } else if (state.playing && !_isPlaying) {
          _isPlaying = true;
          _onPlaybackStarted?.call();
        }
      });
      
      _isInitialized = true;
      print('✅ [PlaylistTTS] 播放器初始化成功');
    } catch (e) {
      print('❌ [PlaylistTTS] 初始化失败: $e');
      _onError?.call('播放器初始化失败: $e');
    }
  }

  /// 设置回调函数
  void setCallbacks({
    VoidCallback? onPlaybackStarted,
    VoidCallback? onPlaybackCompleted,
    Function(String)? onError,
  }) {
    _onPlaybackStarted = onPlaybackStarted;
    _onPlaybackCompleted = onPlaybackCompleted;
    _onError = onError;
  }

  /// 处理新的音频块
  Future<void> processTTSChunk(String messageId, String base64Audio) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      // 检查是否是新消息
      if (_currentMessageId != messageId) {
        await _startNewMessage(messageId);
      }
      
      // 解码并保存音频块
      final audioData = base64Decode(base64Audio);
      final chunkFile = await _saveAudioChunk(messageId, _chunkCounter++, audioData);
      _audioChunkFiles.add(chunkFile);
      
      // 添加到播放列表
      final audioSource = AudioSource.file(chunkFile.path);
      await _playlist!.add(audioSource);
      
      // 如果是第一个音频块，开始播放
      if (_chunkCounter == 1) {
        await _player!.play();
      }
      
      print('📦 [PlaylistTTS] 添加音频块 $_chunkCounter 到播放列表');
    } catch (e) {
      print('❌ [PlaylistTTS] 处理音频块失败: $e');
      _onError?.call('处理音频块失败: $e');
    }
  }

  /// 开始新消息的播放
  Future<void> _startNewMessage(String messageId) async {
    try {
      // 停止当前播放
      await _player?.stop();
      
      // 清空播放列表
      await _playlist?.clear();
      
      // 清理旧的音频文件
      await _cleanupChunkFiles();
      
      // 重置状态
      _currentMessageId = messageId;
      _chunkCounter = 0;
      _audioChunkFiles.clear();
      _isPlaying = false;
      
      print('🔄 [PlaylistTTS] 开始新消息: $messageId');
    } catch (e) {
      print('❌ [PlaylistTTS] 开始新消息失败: $e');
    }
  }

  /// 保存音频块为文件
  Future<File> _saveAudioChunk(String messageId, int chunkIndex, Uint8List audioData) async {
    final tempDir = await getTemporaryDirectory();
    final chunkDir = Directory('${tempDir.path}/tts_chunks/$messageId');
    await chunkDir.create(recursive: true);
    
    final chunkFile = File('${chunkDir.path}/chunk_${chunkIndex.toString().padLeft(3, '0')}.wav');
    await chunkFile.writeAsBytes(audioData);
    
    return chunkFile;
  }

  /// 完成消息播放
  Future<void> finishTTSMessage(String messageId) async {
    if (_currentMessageId == messageId) {
      print('✅ [PlaylistTTS] 消息 $messageId 的所有音频块已接收完成');
      
      // 可选：保存完整的音频文件用于缓存
      await _saveCompleteAudioFile(messageId);
    }
  }

  /// 保存完整音频文件（用于缓存）
  Future<void> _saveCompleteAudioFile(String messageId) async {
    try {
      if (_audioChunkFiles.isEmpty) return;
      
      final tempDir = await getTemporaryDirectory();
      final completeFile = File('${tempDir.path}/tts_complete/$messageId.wav');
      await completeFile.parent.create(recursive: true);
      
      // 合并所有音频块（简单的字节拼接，实际项目中可能需要更复杂的音频合并）
      final sink = completeFile.openWrite();
      for (final chunkFile in _audioChunkFiles) {
        if (await chunkFile.exists()) {
          final bytes = await chunkFile.readAsBytes();
          sink.add(bytes);
        }
      }
      await sink.close();
      
      print('💾 [PlaylistTTS] 完整音频文件已保存: ${completeFile.path}');
    } catch (e) {
      print('⚠️ [PlaylistTTS] 保存完整音频文件失败: $e');
    }
  }

  /// 播放控制方法
  Future<void> play() async {
    if (_player != null && !_isPlaying) {
      await _player!.play();
    }
  }

  Future<void> pause() async {
    if (_player != null && _isPlaying) {
      await _player!.pause();
    }
  }

  Future<void> stop() async {
    if (_player != null) {
      await _player!.stop();
      _isPlaying = false;
    }
  }

  /// 播放指定消息的音频（从缓存）
  Future<void> playMessageAudio(String messageId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final completeFile = File('${tempDir.path}/tts_complete/$messageId.wav');
      
      if (await completeFile.exists()) {
        // 停止当前播放
        await stop();
        
        // 清空播放列表
        await _playlist?.clear();
        
        // 添加完整音频文件到播放列表
        final audioSource = AudioSource.file(completeFile.path);
        await _playlist?.add(audioSource);
        
        // 开始播放
        await _player?.play();
        
        print('🎵 [PlaylistTTS] 播放缓存音频: $messageId');
      } else {
        print('⚠️ [PlaylistTTS] 未找到消息音频缓存: $messageId');
        _onError?.call('未找到音频文件');
      }
    } catch (e) {
      print('❌ [PlaylistTTS] 播放消息音频失败: $e');
      _onError?.call('播放失败: $e');
    }
  }

  /// 清理缓存
  Future<void> clearCache() async {
    try {
      await stop();
      await cleanupAllTempFiles();
      print('🧹 [PlaylistTTS] 缓存已清理');
    } catch (e) {
      print('⚠️ [PlaylistTTS] 清理缓存失败: $e');
    }
  }

  /// 获取播放状态
  bool get isPlaying => _isPlaying;
  bool get isInitialized => _isInitialized;
  String? get currentMessageId => _currentMessageId;
  int get chunkCount => _chunkCounter;

  /// 获取播放状态流
  Stream<bool> get playingStream {
    return _player?.playerStateStream.map((state) => state.playing) ?? Stream.value(false);
  }
  
  /// 获取播放进度流
  Stream<Duration> get positionStream {
    return _player?.positionStream ?? Stream.value(Duration.zero);
  }
  
  /// 获取播放时长流
  Stream<Duration?> get durationStream {
    return _player?.durationStream ?? Stream.value(null);
  }
  
  /// 获取播放器状态流
  Stream<PlayerState>? get playerStateStream => _player?.playerStateStream;

  /// 清理临时文件
  Future<void> _cleanupChunkFiles() async {
    for (final file in _audioChunkFiles) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('⚠️ [PlaylistTTS] 删除临时文件失败: ${file.path}, 错误: $e');
      }
    }
  }

  /// 清理所有临时目录
  Future<void> cleanupAllTempFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final ttsChunksDir = Directory('${tempDir.path}/tts_chunks');
      final ttsCompleteDir = Directory('${tempDir.path}/tts_complete');
      
      if (await ttsChunksDir.exists()) {
        await ttsChunksDir.delete(recursive: true);
      }
      
      if (await ttsCompleteDir.exists()) {
        await ttsCompleteDir.delete(recursive: true);
      }
      
      print('🧹 [PlaylistTTS] 所有临时文件已清理');
    } catch (e) {
      print('⚠️ [PlaylistTTS] 清理临时文件失败: $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    try {
      // 取消订阅
      await _playerStateSubscription?.cancel();
      await _durationSubscription?.cancel();
      await _positionSubscription?.cancel();
      
      // 停止播放并释放播放器
      await _player?.stop();
      await _player?.dispose();
      
      // 清理文件
      await _cleanupChunkFiles();
      
      // 重置状态
      _player = null;
      _playlist = null;
      _audioChunkFiles.clear();
      _currentMessageId = null;
      _chunkCounter = 0;
      _isInitialized = false;
      _isPlaying = false;
      
      print('🔄 [PlaylistTTS] 资源已释放');
    } catch (e) {
      print('⚠️ [PlaylistTTS] 释放资源失败: $e');
    }
  }
}