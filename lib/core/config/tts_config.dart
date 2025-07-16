/// 播放策略枚举
enum PlaybackStrategy {
  /// 立即播放：收到第一个音频块就开始播放
  immediate,
  /// 缓存后播放：等待所有音频块接收完成后再播放
  buffered,
  /// 智能播放：根据网络状况和音频大小自动选择
  smart,
}

/// 详细日志级别
enum LogLevel { none, error, warning, info, debug }

/// 音频质量模式
enum AudioQuality { low, medium, high }

/// TTS配置管理类
/// 管理所有TTS相关的配置参数和播放策略
class TTSConfig {
  static final TTSConfig _instance = TTSConfig._internal();
  factory TTSConfig() => _instance;
  TTSConfig._internal();

  static TTSConfig get instance => _instance;

  // ========== 音频参数配置 ==========
  
  /// 音频采样率（优化为更兼容的采样率）
  int get sampleRate => 22050; // 从16000改为22050，更好的硬件兼容性
  
  /// 音频格式
  String get audioFormat => 'mp3';
  
  /// 音频编码
  String get audioEncoding => 'pcm';
  
  /// 音频通道数
  int get channels => 1;
  
  /// 音频位深度
  int get bitDepth => 16;
  
  /// 是否启用硬件加速（可能导致BAD_INDEX错误）
  bool _hardwareAccelerationEnabled = true;
  bool get hardwareAccelerationEnabled => _hardwareAccelerationEnabled;
  
  /// 设置硬件加速
  void setHardwareAccelerationEnabled(bool enabled) {
    _hardwareAccelerationEnabled = enabled;
    print('🔧 [TTS Config] 硬件加速已${enabled ? "启用" : "禁用"}');
  }
  
  /// 音频缓冲区大小（字节）- 优化以减少编解码器查询
  int get audioBufferSize => 8192; // 4KB缓冲区
  
  /// 是否使用软件解码器（避免硬件兼容性问题）
  bool _useSoftwareDecoder = false;
  bool get useSoftwareDecoder => _useSoftwareDecoder;
  
  /// 设置软件解码器使用
  void setUseSoftwareDecoder(bool enabled) {
    _useSoftwareDecoder = enabled;
    print('💻 [TTS Config] 软件解码器已${enabled ? "启用" : "禁用"}');
  }

  // ========== 播放策略配置 ==========
  
  /// 当前播放策略
  PlaybackStrategy _playbackStrategy = PlaybackStrategy.buffered;
  PlaybackStrategy get playbackStrategy => _playbackStrategy;
  
  /// 设置播放策略
  void setPlaybackStrategy(PlaybackStrategy strategy) {
    _playbackStrategy = strategy;
    print('🎛️ [TTS Config] 播放策略已更改为: ${strategy.name}');
  }
  
  /// 立即播放的最小缓冲大小（字节）
  int get minBufferSizeForImmediatePlay => 8192; // 8KB
  
  /// 智能播放的网络延迟阈值（毫秒）
  int get networkLatencyThreshold => 500;
  
  /// 最大音频块等待时间（毫秒）
  int get maxChunkWaitTime => 5000;

  // ========== 缓存配置 ==========
  
  /// 音频缓存目录名
  String get audioCacheDir => 'tts_audio_cache';
  
  /// 最大缓存文件数量
  int get maxCacheFiles => 300;
  
  /// 缓存文件过期时间（小时）
  int get cacheExpirationHours => 24;
  
  /// 最大缓存大小（MB）
  int get maxCacheSizeMB => 100;
  
  /// 是否启用缓存
  bool _cacheEnabled = true;
  bool get cacheEnabled => _cacheEnabled;
  
  /// 设置缓存启用状态
  void setCacheEnabled(bool enabled) {
    _cacheEnabled = enabled;
    print('💾 [TTS Config] 缓存已${enabled ? "启用" : "禁用"}');
  }

  // ========== 性能配置 ==========
  
  /// 音频块处理超时时间（毫秒）
  int get chunkProcessTimeout => 3000;
  
  /// 播放重试次数
  int get playbackRetryCount => 3;
  
  /// 重试间隔（毫秒）
  int get retryIntervalMs => 1000;
  
  // ========== 音频合并配置 ==========
  
  /// 每个播放段包含的音频块数量（用于减少播放卡顿）
  int _chunksPerSegment = 20;
  int get chunksPerSegment => _chunksPerSegment;
  
  /// 设置每个段的音频块数量
  void setChunksPerSegment(int count) {
    if (count > 0 && count <= 30) {
      _chunksPerSegment = count;
      print('🔧 [TTS Config] 每段音频块数量已设置为: $count');
    } else {
      print('⚠️ [TTS Config] 无效的音频块数量: $count (范围: 1-30)');
    }
  }
  
  /// 是否启用音频块合并
  bool _chunkMergingEnabled = true;
  bool get chunkMergingEnabled => _chunkMergingEnabled;
  
  /// 设置音频块合并启用状态
  void setChunkMergingEnabled(bool enabled) {
    _chunkMergingEnabled = enabled;
    print('🔀 [TTS Config] 音频块合并已${enabled ? "启用" : "禁用"}');
  }
  
  /// 第一段的特殊处理（减少初始延迟）
  bool _fastFirstSegment = false; // 启用第一段快速播放，减少初始延迟
  bool get fastFirstSegment => _fastFirstSegment;
  
  /// 设置第一段快速播放
  void setFastFirstSegment(bool enabled) {
    _fastFirstSegment = enabled;
    print('⚡ [TTS Config] 第一段快速播放已${enabled ? "启用" : "禁用"}');
  }
  
  /// 是否启用预加载
  bool _preloadEnabled = true;
  bool get preloadEnabled => _preloadEnabled;
  
  /// 设置预加载启用状态
  void setPreloadEnabled(bool enabled) {
    _preloadEnabled = enabled;
    print('⚡ [TTS Config] 预加载已${enabled ? "启用" : "禁用"}');
  }

  // ========== 音频切换优化配置 ==========
  
  /// 启用平滑切换（减少卡顿）
  bool _enableSmoothSwitching = true;
  bool get enableSmoothSwitching => _enableSmoothSwitching;
  
  /// 平滑停止延迟（毫秒）
  int _smoothStopDelayMs = 50;
  int get smoothStopDelayMs => _smoothStopDelayMs;
  
  /// 缓存播放平滑切换延迟（毫秒）
  int _cachePlaySmoothDelayMs = 30;
  int get cachePlaySmoothDelayMs => _cachePlaySmoothDelayMs;
  
  /// 启用智能播放列表管理
  bool _enableSmartPlaylistManagement = true;
  bool get enableSmartPlaylistManagement => _enableSmartPlaylistManagement;
  
  /// 启用异步文件清理
  bool _enableAsyncFileCleanup = true;
  bool get enableAsyncFileCleanup => _enableAsyncFileCleanup;
  
  /// 启用文件存在性检查
  bool _enableFileExistenceCheck = true;
  bool get enableFileExistenceCheck => _enableFileExistenceCheck;
  
  /// 启用异步缓存统计
  bool _enableAsyncCacheStats = true;
  bool get enableAsyncCacheStats => _enableAsyncCacheStats;
  
  /// 设置平滑切换启用状态
  void setEnableSmoothSwitching(bool enabled) {
    _enableSmoothSwitching = enabled;
    print('🎵 [TTS Config] 平滑切换已${enabled ? "启用" : "禁用"}');
  }
  
  /// 设置平滑停止延迟
  void setSmoothStopDelayMs(int delayMs) {
    if (delayMs >= 0 && delayMs <= 500) {
      _smoothStopDelayMs = delayMs;
      print('⏱️ [TTS Config] 平滑停止延迟已设置为: ${delayMs}ms');
    } else {
      print('⚠️ [TTS Config] 无效的延迟时间: $delayMs (范围: 0-500ms)');
    }
  }
  
  /// 设置缓存播放平滑切换延迟
  void setCachePlaySmoothDelayMs(int delayMs) {
    if (delayMs >= 0 && delayMs <= 200) {
      _cachePlaySmoothDelayMs = delayMs;
      print('⏱️ [TTS Config] 缓存播放平滑切换延迟已设置为: ${delayMs}ms');
    } else {
      print('⚠️ [TTS Config] 无效的延迟时间: $delayMs (范围: 0-200ms)');
    }
  }
  
  /// 设置智能播放列表管理启用状态
  void setEnableSmartPlaylistManagement(bool enabled) {
    _enableSmartPlaylistManagement = enabled;
    print('🎵 [TTS Config] 智能播放列表管理已${enabled ? "启用" : "禁用"}');
  }
  
  /// 设置异步文件清理启用状态
  void setEnableAsyncFileCleanup(bool enabled) {
    _enableAsyncFileCleanup = enabled;
    print('🧹 [TTS Config] 异步文件清理已${enabled ? "启用" : "禁用"}');
  }
  
  /// 设置文件存在性检查启用状态
  void setEnableFileExistenceCheck(bool enabled) {
    _enableFileExistenceCheck = enabled;
    print('📁 [TTS Config] 文件存在性检查已${enabled ? "启用" : "禁用"}');
  }
  
  /// 设置异步缓存统计启用状态
  void setEnableAsyncCacheStats(bool enabled) {
    _enableAsyncCacheStats = enabled;
    print('📊 [TTS Config] 异步缓存统计已${enabled ? "启用" : "禁用"}');
  }

  // ========== 调试配置 ==========
  
  /// 调试模式
  bool _debugMode = false;
  bool get debugMode => _debugMode;
  
  /// 设置调试模式
  void setDebugMode(bool enabled) {
    _debugMode = enabled;
    print('🐛 [TTS Config] 调试模式已${enabled ? "启用" : "禁用"}');
  }
  
  LogLevel _logLevel = LogLevel.info;
  LogLevel get logLevel => _logLevel;
  
  /// 设置日志级别
  void setLogLevel(LogLevel level) {
    _logLevel = level;
    print('📝 [TTS Config] 日志级别已设置为: ${level.name}');
  }
  
  /// 是否记录性能指标
  bool _performanceMetricsEnabled = false;
  bool get performanceMetricsEnabled => _performanceMetricsEnabled;
  
  /// 设置性能指标记录
  void setPerformanceMetricsEnabled(bool enabled) {
    _performanceMetricsEnabled = enabled;
    print('📊 [TTS Config] 性能指标记录已${enabled ? "启用" : "禁用"}');
  }

  // ========== 用户体验配置 ==========
  
  /// 播放进度更新间隔（毫秒）
  int get progressUpdateIntervalMs => 100;
  
  /// 是否显示播放进度
  bool _showPlaybackProgress = true;
  bool get showPlaybackProgress => _showPlaybackProgress;
  
  /// 设置播放进度显示
  void setShowPlaybackProgress(bool enabled) {
    _showPlaybackProgress = enabled;
    print('📈 [TTS Config] 播放进度显示已${enabled ? "启用" : "禁用"}');
  }
  
  AudioQuality _audioQuality = AudioQuality.medium;
  AudioQuality get audioQuality => _audioQuality;
  
  /// 设置音频质量
  void setAudioQuality(AudioQuality quality) {
    _audioQuality = quality;
    print('🎵 [TTS Config] 音频质量已设置为: ${quality.name}');
  }

  // ========== 配置重置 ==========
  
  /// 重置为默认配置
  void resetToDefaults() {
    _playbackStrategy = PlaybackStrategy.immediate;
    _cacheEnabled = true;
    _preloadEnabled = true;
    _chunksPerSegment = 10;
    _chunkMergingEnabled = true;
    _fastFirstSegment = false; // 改为false，确保一致的合并行为
    _hardwareAccelerationEnabled = false;
    _useSoftwareDecoder = true;
    _debugMode = false;
    _logLevel = LogLevel.info;
    _performanceMetricsEnabled = false;
    _showPlaybackProgress = true;
    _audioQuality = AudioQuality.medium;
    
    // 音频切换优化配置
    _enableSmoothSwitching = true;
    _smoothStopDelayMs = 50;
    _cachePlaySmoothDelayMs = 30;
    _enableSmartPlaylistManagement = true;
    _enableAsyncFileCleanup = true;
    _enableFileExistenceCheck = true;
    _enableAsyncCacheStats = true;
    
    print('🔄 [TTS Config] 配置已重置为默认值');
  }
  
  /// 获取当前配置摘要
  Map<String, dynamic> getConfigSummary() {
    return {
      'playbackStrategy': _playbackStrategy.name,
      'cacheEnabled': _cacheEnabled,
      'preloadEnabled': _preloadEnabled,
      'chunksPerSegment': _chunksPerSegment,
      'chunkMergingEnabled': _chunkMergingEnabled,
      'fastFirstSegment': _fastFirstSegment,
      'debugMode': _debugMode,
      'logLevel': _logLevel.name,
      'performanceMetricsEnabled': _performanceMetricsEnabled,
      'showPlaybackProgress': _showPlaybackProgress,
      'audioQuality': _audioQuality.name,
      'sampleRate': sampleRate,
      'audioFormat': audioFormat,
      'maxCacheFiles': maxCacheFiles,
      'cacheExpirationHours': cacheExpirationHours,
      // 音频切换优化配置
      'enableSmoothSwitching': _enableSmoothSwitching,
      'smoothStopDelayMs': _smoothStopDelayMs,
      'cachePlaySmoothDelayMs': _cachePlaySmoothDelayMs,
      'enableSmartPlaylistManagement': _enableSmartPlaylistManagement,
      'enableAsyncFileCleanup': _enableAsyncFileCleanup,
      'enableFileExistenceCheck': _enableFileExistenceCheck,
      'enableAsyncCacheStats': _enableAsyncCacheStats,
    };
  }
}