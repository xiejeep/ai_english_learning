import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../config/tts_config.dart';
import '../utils/tts_logger.dart';
import '../utils/tts_performance_monitor.dart';
import '../utils/file_system_health_checker.dart';
import '../utils/tts_retry_handler.dart';
import '../utils/tts_cache_diagnostics.dart';
import 'tts_cache_service.dart';

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
  
  // 音频块缓冲合并相关
  final List<Uint8List> _audioChunkBuffer = [];
  int _segmentCounter = 0;
  bool _isFirstSegment = true;
  bool _isCreatingSegment = false; // 段创建锁，防止并发问题
  
  // 优化的锁机制：音频块处理队列
  final List<Uint8List> _pendingChunks = []; // 等待处理的音频块队列
  bool _isProcessingQueue = false; // 队列处理锁
  
  // 配置
  final TTSConfig _config = TTSConfig.instance;
  
  // 缓存服务
  final TTSCacheService _cacheService = TTSCacheService.instance;
  
  // 消息文本存储（用于缓存）
  final Map<String, String> _messageTexts = {};
  
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
      TTSPerformanceMonitor.startTimer('initialize');
      
      // 检查文件系统健康状态
      final isStorageHealthy = await FileSystemHealthChecker.checkStorageHealth();
      if (!isStorageHealthy) {
        TTSLogger.warning('存储系统健康检查失败，但继续初始化');
      }
      
      // 启用性能监控
      TTSPerformanceMonitor.enable();
      
      // 初始化缓存服务并进行诊断
      try {
        await _cacheService.initialize();
        TTSLogger.success('缓存服务初始化成功');
        
        // 获取缓存统计信息
        final cacheStats = await _cacheService.getCacheStats();
        TTSLogger.info('缓存统计: ${cacheStats['fileCount']} 个文件, ${cacheStats['totalSizeMB'].toStringAsFixed(2)} MB');
        
        // 如果缓存为空，运行诊断
        if (cacheStats['fileCount'] == 0) {
          TTSLogger.warning('缓存为空，运行诊断检查...');
          await _runCacheDiagnostics();
        }
        
      } catch (e) {
        TTSLogger.error('缓存服务初始化失败: $e');
        
        // 运行完整诊断
        TTSLogger.info('运行缓存诊断以确定问题...');
        await _runCacheDiagnostics();
        
        // 尝试修复
        TTSLogger.info('尝试修复缓存问题...');
        final repairResult = await TTSCacheDiagnostics.repairCache();
        if (repairResult['success']) {
          TTSLogger.success('缓存修复成功: ${repairResult['actions']}');
          // 重新尝试初始化
          await _cacheService.initialize();
        } else {
          TTSLogger.error('缓存修复失败: ${repairResult['error']}');
        }
      }
      
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
      TTSLogger.success('播放器初始化成功');
      TTSPerformanceMonitor.recordEvent('initialize_success');
    } catch (e) {
      TTSLogger.error('初始化失败: $e');
      TTSPerformanceMonitor.recordEvent('initialize_error', data: {'error': e.toString()});
      _onError?.call('播放器初始化失败: $e');
    } finally {
      TTSPerformanceMonitor.endTimer('initialize');
    }
  }
  
  /// 运行缓存诊断
  Future<void> _runCacheDiagnostics() async {
    try {
      final diagnostics = await TTSCacheDiagnostics.runFullDiagnostics();
      final report = TTSCacheDiagnostics.generateReport(diagnostics);
      
      TTSLogger.info('缓存诊断报告:\n$report');
      
      final summary = diagnostics['summary'] as Map<String, dynamic>?;
      if (summary != null && !summary['isHealthy']) {
        TTSLogger.warning('缓存系统存在问题，建议查看诊断报告');
      }
    } catch (e) {
      TTSLogger.error('运行缓存诊断失败: $e');
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

  /// 设置消息文本（用于缓存）
  void setMessageText(String messageId, String messageText) {
    _messageTexts[messageId] = messageText;
    print('📝 [PlaylistTTS] 已存储消息文本: $messageId (${messageText.length} 字符)');
  }

  /// 获取消息文本
  String? getMessageText(String messageId) {
    return _messageTexts[messageId];
  }

  /// 处理带缓存的TTS请求
  /// 如果存在缓存，直接播放；否则处理音频流
  Future<bool> processTTSWithCache(String messageId, String messageText) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      TTSPerformanceMonitor.startTimer('processTTSWithCache');
      TTSPerformanceMonitor.incrementCounter('tts_requests');
      
      // 存储消息文本用于后续缓存
      _messageTexts[messageId] = messageText;
      
      // 检查是否存在缓存
      TTSPerformanceMonitor.startTimer('cache_lookup');
      
      bool hasCachedAudio = false;
      String? cachedPath;
      
      try {
        hasCachedAudio = await _cacheService.hasCachedAudio(messageText);
        if (hasCachedAudio) {
          cachedPath = await _cacheService.getCachedAudioPath(messageText);
        }
        TTSPerformanceMonitor.endTimer('cache_lookup');
      } catch (e) {
        TTSPerformanceMonitor.endTimer('cache_lookup');
        TTSLogger.warning('缓存查找失败: $e，将跳过缓存');
        
        // 缓存查找失败，但不影响主流程
        hasCachedAudio = false;
        cachedPath = null;
      }
      
      if (hasCachedAudio && cachedPath != null) {
        TTSPerformanceMonitor.incrementCounter('cache_hits');
        
        try {
          await _playFromCache(messageId, cachedPath);
          TTSLogger.cache('使用缓存音频播放: $messageId');
          return true; // 使用了缓存
        } catch (e) {
          TTSLogger.error('播放缓存音频失败: $e，将重新生成音频');
          TTSPerformanceMonitor.recordEvent('cache_play_failed', data: {
            'messageId': messageId,
            'error': e.toString(),
          });
          
          // 缓存播放失败，删除可能损坏的缓存文件
          try {
            final file = File(cachedPath);
            if (await file.exists()) {
              await file.delete();
              TTSLogger.info('已删除损坏的缓存文件: $cachedPath');
            }
          } catch (deleteError) {
            TTSLogger.warning('删除损坏缓存文件失败: $deleteError');
          }
          
          // 继续到音频流处理
        }
      } else {
        TTSPerformanceMonitor.incrementCounter('cache_misses');
        TTSLogger.info('未找到音频缓存: $messageId');
      }
      
      // 没有缓存或缓存播放失败，准备接收音频流
      await _startNewMessage(messageId);
      TTSLogger.info('准备接收音频流: $messageId');
      return false; // 需要接收音频流
      
    } catch (e) {
      TTSLogger.error('处理缓存TTS请求失败: $e');
      TTSPerformanceMonitor.recordEvent('tts_error', data: {'error': e.toString()});
      _onError?.call('处理TTS请求失败: $e');
      return false;
    } finally {
      TTSPerformanceMonitor.endTimer('processTTSWithCache');
    }
  }
  
  /// 从缓存播放音频
  Future<void> _playFromCache(String messageId, String cachedPath) async {
    try {
      await TTSRetryHandler.executeWithRetry(
        'playFromCache',
        () async {
          TTSPerformanceMonitor.startTimer('play_from_cache');
          
          // 验证缓存文件
          final file = File(cachedPath);
          if (!await file.exists()) {
            throw FileSystemException('缓存文件不存在', cachedPath);
          }
          
          final stat = await file.stat();
          if (stat.size < 1024) {
            throw FileSystemException('缓存文件太小，可能已损坏', cachedPath);
          }
          
          // 停止当前播放
          await stop();
          
          // 清空播放列表
          await _playlist?.clear();
          
          // 重置状态
          _currentMessageId = messageId;
          _chunkCounter = 0;
          _segmentCounter = 0;
          _isFirstSegment = true;
          _isCreatingSegment = false;
          _audioChunkFiles.clear();
          _audioChunkBuffer.clear();
          _isPlaying = false;
          
          // 添加缓存音频到播放列表
          final audioSource = AudioSource.file(cachedPath);
          await _playlist?.add(audioSource);
          
          // 开始播放
          await _player?.play();
          
          TTSLogger.playback('开始播放缓存音频: $messageId');
          TTSPerformanceMonitor.recordEvent('cache_play_success', data: {
            'messageId': messageId,
            'fileSize': stat.size,
          });
        },
        maxRetries: 2,
        shouldRetry: (error) {
          // 对于文件系统错误和播放器错误进行重试
          return TTSRetryHandler.isRetryableError(error) ||
                 error.toString().contains('FileSystemException') ||
                 error.toString().contains('player');
        },
      );
    } catch (e) {
      TTSLogger.error('播放缓存音频失败: $e');
      TTSPerformanceMonitor.recordEvent('cache_play_error', data: {
        'messageId': messageId,
        'error': e.toString(),
      });
      _onError?.call('播放缓存音频失败: $e');
    } finally {
      TTSPerformanceMonitor.endTimer('play_from_cache');
    }
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
        
        // 🔧 检查消息文本是否已存储（备用机制）
        if (!_messageTexts.containsKey(messageId)) {
          print('⚠️ [PlaylistTTS] 消息文本未预先存储: $messageId');
          print('💡 [PlaylistTTS] 提示：请确保在调用processTTSChunk前先调用processTTSWithCache或setMessageText');
          print('🔍 [PlaylistTTS] 当前存储的消息ID: ${_messageTexts.keys.toList()}');
          
          // 可以在这里添加从其他服务获取消息文本的逻辑
          // 例如：从消息服务、数据库或其他缓存中获取
          // final messageText = await _messageService.getMessageText(messageId);
          // if (messageText != null) {
          //   setMessageText(messageId, messageText);
          // }
        }
      }
      
      // 解码音频数据
      final audioData = base64Decode(base64Audio);
      _chunkCounter++;
      
      if (_config.chunkMergingEnabled) {
        // 使用缓冲合并机制
        await _processChunkWithBuffering(messageId, audioData);
      } else {
        // 使用原始的单块处理机制
        await _processSingleChunk(messageId, audioData);
      }
      
      print('📦 [PlaylistTTS] 处理音频块 $_chunkCounter (${_config.chunkMergingEnabled ? "缓冲模式" : "单块模式"})');
    } catch (e) {
      print('❌ [PlaylistTTS] 处理音频块失败: $e');
      _onError?.call('处理音频块失败: $e');
    }
  }
  
  /// 使用缓冲合并机制处理音频块（优化版本）
  Future<void> _processChunkWithBuffering(String messageId, Uint8List audioData) async {
    // 将音频块添加到待处理队列
    _pendingChunks.add(audioData);
    
    print('🔄 [PlaylistTTS] 音频块已加入队列，队列长度: ${_pendingChunks.length}, 缓冲区: ${_audioChunkBuffer.length}, 正在创建段: $_isCreatingSegment');
    
    // 如果队列处理器没有运行，启动它
    if (!_isProcessingQueue) {
      _processChunkQueue(messageId);
    }
  }
  
  /// 处理音频块队列（确保所有音频块都被处理）
  Future<void> _processChunkQueue(String messageId) async {
    if (_isProcessingQueue) return;
    
    _isProcessingQueue = true;
    
    try {
      while (_pendingChunks.isNotEmpty) {
        // 从队列中取出音频块并添加到缓冲区
        final chunk = _pendingChunks.removeAt(0);
        _audioChunkBuffer.add(chunk);
        
        print('📦 [PlaylistTTS] 处理队列中的音频块，缓冲区现有: ${_audioChunkBuffer.length} 个音频块');
        
        // 检查是否需要创建段
        bool shouldCreateSegment = false;
        
        if (_isFirstSegment && _config.fastFirstSegment) {
          // 第一段：收到第一个块就立即播放（减少延迟）
          shouldCreateSegment = _audioChunkBuffer.isNotEmpty;
        } else {
          // 后续段：等待指定数量的块
          shouldCreateSegment = _audioChunkBuffer.length >= _config.chunksPerSegment;
        }
        
        if (shouldCreateSegment && !_isCreatingSegment) {
          await _createAndPlaySegment(messageId);
          // 段创建完成后，继续处理队列中剩余的音频块
        }
        
        // 如果正在创建段，暂停队列处理，等待段创建完成
        if (_isCreatingSegment) {
          print('⏳ [PlaylistTTS] 段创建中，暂停队列处理');
          break;
        }
      }
    } catch (e) {
      print('❌ [PlaylistTTS] 处理音频块队列失败: $e');
    } finally {
      _isProcessingQueue = false;
      
      // 如果队列中还有待处理的音频块，重新启动处理器
      if (_pendingChunks.isNotEmpty) {
        print('🔄 [PlaylistTTS] 队列中还有 ${_pendingChunks.length} 个音频块待处理，重新启动处理器');
        _processChunkQueue(messageId);
      }
    }
  }
  
  /// 创建并播放音频段
  Future<void> _createAndPlaySegment(String messageId) async {
    if (_audioChunkBuffer.isEmpty) return;
    
    // 设置段创建锁
    if (_isCreatingSegment) {
      print('⚠️ [PlaylistTTS] 段创建已在进行中，跳过重复调用');
      return;
    }
    
    _isCreatingSegment = true;
    
    try {
      final chunkCount = _audioChunkBuffer.length;
      final currentSegmentIndex = _segmentCounter + 1; // 下一个段的索引
      
      print('🎵 [PlaylistTTS] 开始创建音频段 $currentSegmentIndex，包含 $chunkCount 个音频块');
      
      // 创建当前缓冲区的副本，然后立即清空缓冲区
      final chunksToProcess = List<Uint8List>.from(_audioChunkBuffer);
      _audioChunkBuffer.clear();
      
      // 合并音频数据
      final mergedAudioData = _mergeAudioChunks(chunksToProcess);
      
      // 保存合并后的音频段
      final segmentFile = await _saveAudioSegment(messageId, currentSegmentIndex, mergedAudioData);
      _audioChunkFiles.add(segmentFile);
      
      // 添加到播放列表
      final audioSource = AudioSource.file(segmentFile.path);
      await _playlist!.add(audioSource);
      
      // 只有在成功创建段后才递增计数器
      _segmentCounter++;
      
      // 如果是第一个音频段，开始播放
      if (_segmentCounter == 1) {
        await _player!.play();
        _isFirstSegment = false;
        print('▶️ [PlaylistTTS] 开始播放第一个音频段');
      }
      
      print('✅ [PlaylistTTS] 音频段 $currentSegmentIndex 创建成功，已添加到播放列表');
    } catch (e) {
      print('❌ [PlaylistTTS] 创建音频段失败: $e');
      _onError?.call('创建音频段失败: $e');
      // 发生错误时不递增计数器，保持状态一致性
    } finally {
      // 无论成功还是失败，都要释放锁
      _isCreatingSegment = false;
      print('🔓 [PlaylistTTS] 段创建锁已释放');
      
      // 段创建完成后，如果队列中还有待处理的音频块，重新启动队列处理器
      if (_pendingChunks.isNotEmpty && !_isProcessingQueue) {
        print('🔄 [PlaylistTTS] 段创建完成，重新启动队列处理器处理剩余的 ${_pendingChunks.length} 个音频块');
        _processChunkQueue(messageId);
      }
    }
  }
  
  /// 合并多个音频块的数据
  Uint8List _mergeAudioChunks(List<Uint8List> chunks) {
    if (chunks.isEmpty) return Uint8List(0);
    if (chunks.length == 1) return chunks.first;
    
    // 计算总长度
    int totalLength = chunks.fold(0, (sum, chunk) => sum + chunk.length);
    
    // 创建合并后的数据
    final mergedData = Uint8List(totalLength);
    int offset = 0;
    
    for (final chunk in chunks) {
      mergedData.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    return mergedData;
  }
  
  /// 使用原始的单块处理机制
  Future<void> _processSingleChunk(String messageId, Uint8List audioData) async {
    // 保存音频块
    final chunkFile = await _saveAudioChunk(messageId, _chunkCounter, audioData);
    _audioChunkFiles.add(chunkFile);
    
    // 添加到播放列表
    final audioSource = AudioSource.file(chunkFile.path);
    await _playlist!.add(audioSource);
    
    // 如果是第一个音频块，开始播放
    if (_chunkCounter == 1) {
      await _player!.play();
    }
  }

  /// 开始新消息的播放
  Future<void> _startNewMessage(String messageId) async {
    try {
      // 如果是同一个消息，不需要重新初始化
      if (_currentMessageId == messageId && _isPlaying) {
        print('🔄 [PlaylistTTS] 继续播放消息: $messageId');
        return;
      }
      
      // 平滑停止当前播放（避免突然中断）
      if (_config.enableSmoothSwitching && _player?.playing == true) {
        await _player?.pause();
        // 给一个短暂的延迟让音频平滑停止
        await Future.delayed(Duration(milliseconds: _config.smoothStopDelayMs));
      } else if (_player?.playing == true) {
        await _player?.stop();
      }
      
      // 异步清理旧文件（不阻塞主流程）
      if (_config.enableAsyncFileCleanup && _currentMessageId != null && _currentMessageId != messageId) {
        _cleanupChunkFiles(); // 移除await，异步执行
      } else if (_currentMessageId != null && _currentMessageId != messageId) {
        await _cleanupChunkFiles();
      }
      
      // 智能播放列表管理：只在必要时清空
      if (_config.enableSmartPlaylistManagement) {
        if (_currentMessageId != messageId) {
          // 只有切换到不同消息时才清空播放列表
          await _playlist?.clear();
          print('🧹 [PlaylistTTS] 清空播放列表 (切换消息)');
        }
      } else {
        // 传统方式：总是清空播放列表
        await _playlist?.clear();
      }
      
      // 重置状态
      _currentMessageId = messageId;
      _chunkCounter = 0;
      _segmentCounter = 0;
      _isFirstSegment = true;
      _isCreatingSegment = false; // 重置段创建锁
      _audioChunkFiles.clear();
      _audioChunkBuffer.clear();
      _isPlaying = false;
      
      // 重置优化锁机制相关状态
      _pendingChunks.clear();
      _isProcessingQueue = false;
      
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
  
  /// 保存音频段为文件（合并后的音频块）
  Future<File> _saveAudioSegment(String messageId, int segmentIndex, Uint8List audioData) async {
    final tempDir = await getTemporaryDirectory();
    final segmentDir = Directory('${tempDir.path}/tts_segments/$messageId');
    await segmentDir.create(recursive: true);
    
    final segmentFile = File('${segmentDir.path}/segment_${segmentIndex.toString().padLeft(3, '0')}.wav');
    await segmentFile.writeAsBytes(audioData);
    
    return segmentFile;
  }

  /// 完成消息播放
  Future<void> finishTTSMessage(String messageId) async {
    print('🏁 [PlaylistTTS] 开始完成消息处理: $messageId');
    print('🔍 [PlaylistTTS] 当前消息ID: $_currentMessageId');
    print('🔍 [PlaylistTTS] 音频块文件数量: ${_audioChunkFiles.length}');
    print('🔍 [PlaylistTTS] 缓冲区音频块数量: ${_audioChunkBuffer.length}');
    print('🔍 [PlaylistTTS] 待处理队列音频块数量: ${_pendingChunks.length}');
    
    if (_currentMessageId == messageId) {
      // 确保所有待处理的音频块都被处理完成
      if (_config.chunkMergingEnabled && _pendingChunks.isNotEmpty) {
        print('🔄 [PlaylistTTS] 处理队列中剩余的 ${_pendingChunks.length} 个音频块');
        // 等待队列处理完成
        while (_pendingChunks.isNotEmpty || _isProcessingQueue) {
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
      
      // 如果启用了缓冲合并且缓冲区还有剩余的音频块，创建最后一个段
      if (_config.chunkMergingEnabled && _audioChunkBuffer.isNotEmpty) {
        await _createAndPlaySegment(messageId);
        print('🎯 [PlaylistTTS] 处理缓冲区剩余的音频块');
      }
      
      print('✅ [PlaylistTTS] 消息 $messageId 的所有音频块已接收完成');
      
      // 保存完整的音频文件用于缓存
      await _saveCompleteAudioFile(messageId);
    } else {
      print('⚠️ [PlaylistTTS] 消息ID不匹配，跳过完成处理: 期望=$_currentMessageId, 实际=$messageId');
    }
  }

  /// 保存完整音频文件（用于缓存）
  Future<void> _saveCompleteAudioFile(String messageId) async {
    try {
      print('💾 [PlaylistTTS] 开始保存完整音频文件: $messageId');
      
      // 获取消息文本
      final messageText = _messageTexts[messageId];
      if (messageText == null) {
        print('⚠️ [PlaylistTTS] 未找到消息文本，无法缓存: $messageId');
        print('🔍 [PlaylistTTS] 当前存储的消息文本: ${_messageTexts.keys.toList()}');
        return;
      }
      
      print('📝 [PlaylistTTS] 消息文本长度: ${messageText.length} 字符');
      print('📝 [PlaylistTTS] 消息文本预览: ${messageText.substring(0, messageText.length > 50 ? 50 : messageText.length)}...');
      
      if (_audioChunkFiles.isEmpty) {
        print('⚠️ [PlaylistTTS] 没有音频块文件，无法创建完整音频: $messageId');
        return;
      }
      
      print('🔍 [PlaylistTTS] 准备合并 ${_audioChunkFiles.length} 个音频块文件');
      
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/tts_temp/$messageId.mp3');
      await tempFile.parent.create(recursive: true);
      
      print('📁 [PlaylistTTS] 临时文件路径: ${tempFile.path}');
      
      // 合并所有音频块（简单的字节拼接，实际项目中可能需要更复杂的音频合并）
      final sink = tempFile.openWrite();
      int totalBytes = 0;
      
      for (int i = 0; i < _audioChunkFiles.length; i++) {
        final chunkFile = _audioChunkFiles[i];
        if (await chunkFile.exists()) {
          final bytes = await chunkFile.readAsBytes();
          sink.add(bytes);
          totalBytes += bytes.length;
          print('📦 [PlaylistTTS] 合并音频块 ${i + 1}/${_audioChunkFiles.length}: ${bytes.length} 字节');
        } else {
          print('⚠️ [PlaylistTTS] 音频块文件不存在: ${chunkFile.path}');
        }
      }
      await sink.close();
      
      print('📊 [PlaylistTTS] 合并完成，总大小: $totalBytes 字节');
      
      // 验证临时文件
      if (await tempFile.exists()) {
        final fileSize = await tempFile.length();
        print('✅ [PlaylistTTS] 临时文件创建成功，大小: $fileSize 字节');
        
        if (fileSize > 0) {
          // 使用TTSCacheService缓存音频文件
          try {
            print('💾 [PlaylistTTS] 开始缓存音频文件...');
            final cachedPath = await _cacheService.cacheAudioFile(messageText, tempFile.path);
            print('✅ [PlaylistTTS] 音频已缓存: ${cachedPath.split('/').last}');
            
            // 验证缓存是否成功
            final hasCached = await _cacheService.hasCachedAudio(messageText);
            print('🔍 [PlaylistTTS] 缓存验证结果: $hasCached');
            
            // 获取缓存统计
            final stats = await _cacheService.getCacheStats();
            print('📊 [PlaylistTTS] 缓存统计: ${stats['fileCount']} 个文件, ${stats['totalSizeMB'].toStringAsFixed(2)} MB');
            
          } catch (cacheError) {
            print('❌ [PlaylistTTS] 缓存音频文件失败: $cacheError');
          }
        } else {
          print('❌ [PlaylistTTS] 临时文件为空，无法缓存');
        }
        
        // 删除临时文件
        try {
          await tempFile.delete();
          print('🗑️ [PlaylistTTS] 临时文件已删除');
        } catch (deleteError) {
          print('⚠️ [PlaylistTTS] 删除临时文件失败: $deleteError');
        }
      } else {
        print('❌ [PlaylistTTS] 临时文件创建失败');
      }
      
      // 清理消息文本记录
      _messageTexts.remove(messageId);
      print('🧹 [PlaylistTTS] 已清理消息文本记录: $messageId');
      
    } catch (e, stackTrace) {
      print('❌ [PlaylistTTS] 保存完整音频文件失败: $e');
      print('📍 [PlaylistTTS] 错误堆栈: $stackTrace');
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
  Future<void> playMessageAudio(String messageText) async {
    try {
      print('🔍 [PlaylistTTS] 尝试播放缓存音频');
      print('📝 [PlaylistTTS] 查找内容: ${messageText.substring(0, messageText.length > 100 ? 100 : messageText.length)}...');
      
      // 异步查找缓存音频（避免阻塞UI）
      final hasCached = await _cacheService.hasCachedAudio(messageText);
      if (hasCached) {
        final cachedPath = await _cacheService.getCachedAudioPath(messageText);
        
        // 检查文件是否存在（如果启用了文件存在性检查）
        final fileExists = _config.enableFileExistenceCheck 
            ? (cachedPath != null && await File(cachedPath).exists())
            : cachedPath != null;
            
        if (fileExists) {
          print('✅ [PlaylistTTS] 找到缓存音频: ${cachedPath.split('/').last}');
          
          // 平滑停止当前播放
          if (_config.enableSmoothSwitching && _player?.playing == true) {
            await _player?.pause();
            await Future.delayed(Duration(milliseconds: _config.cachePlaySmoothDelayMs));
          } else if (_player?.playing == true) {
            await stop();
          }
          
          // 智能播放列表管理：尝试复用现有播放器状态
          final audioSource = AudioSource.file(cachedPath);
          
          if (_config.enableSmartPlaylistManagement) {
            // 检查是否可以直接切换音频源
            if (_playlist?.length == 0) {
              // 播放列表为空，直接添加
              await _playlist?.add(audioSource);
            } else {
              // 播放列表不为空，清空后添加（减少操作）
              await _playlist?.clear();
              await _playlist?.add(audioSource);
            }
          } else {
            // 传统方式：总是清空后添加
            await _playlist?.clear();
            await _playlist?.add(audioSource);
          }
          
          // 重置播放位置到开头，确保从头开始播放
          await _player?.seek(Duration.zero);
          
          // 开始播放
          await _player?.play();
          _isPlaying = true;
          
          print('🎵 [PlaylistTTS] 播放缓存音频: ${cachedPath.split('/').last}');
          return;
        } else {
          print('⚠️ [PlaylistTTS] 缓存文件不存在或路径为空');
        }
      } else {
        print('⚠️ [PlaylistTTS] 未找到音频缓存');
        
        // 异步获取缓存统计信息（不阻塞主流程）
        if (_config.enableAsyncCacheStats) {
          _cacheService.getCacheStats().then((stats) {
            print('📊 [PlaylistTTS] 缓存统计: ${stats['fileCount']} 个文件, ${stats['totalSizeMB']} MB');
          });
        } else {
          final stats = await _cacheService.getCacheStats();
          print('📊 [PlaylistTTS] 缓存统计: ${stats['fileCount']} 个文件, ${stats['totalSizeMB']} MB');
        }
      }
      
      _onError?.call('未找到音频文件');
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
      await _cacheService.clearAllCache(); // 清理TTS缓存
      print('🧹 [PlaylistTTS] 缓存已清理');
    } catch (e) {
      print('⚠️ [PlaylistTTS] 清理缓存失败: $e');
    }
  }
  
  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }
  
  /// 检查是否存在缓存
  Future<bool> hasCachedAudio(String messageText) async {
    return await _cacheService.hasCachedAudio(messageText);
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
      final ttsSegmentsDir = Directory('${tempDir.path}/tts_segments');
      final ttsCompleteDir = Directory('${tempDir.path}/tts_complete');
      
      if (await ttsChunksDir.exists()) {
        await ttsChunksDir.delete(recursive: true);
      }
      
      if (await ttsSegmentsDir.exists()) {
        await ttsSegmentsDir.delete(recursive: true);
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