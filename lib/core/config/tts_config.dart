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
  
  /// 音频采样率
  int get sampleRate => 16000;
  
  /// 音频格式
  String get audioFormat => 'wav';
  
  /// 音频编码
  String get audioEncoding => 'pcm';
  
  /// 音频通道数
  int get channels => 1;
  
  /// 音频位深度
  int get bitDepth => 16;

  // ========== 播放策略配置 ==========
  
  /// 当前播放策略
  PlaybackStrategy _playbackStrategy = PlaybackStrategy.immediate;
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
  int get maxCacheFiles => 100;
  
  /// 缓存文件过期时间（小时）
  int get cacheExpirationHours => 24;
  
  /// 最大缓存大小（MB）
  int get maxCacheSizeMB => 50;
  
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
  
  /// 是否启用预加载
  bool _preloadEnabled = true;
  bool get preloadEnabled => _preloadEnabled;
  
  /// 设置预加载启用状态
  void setPreloadEnabled(bool enabled) {
    _preloadEnabled = enabled;
    print('⚡ [TTS Config] 预加载已${enabled ? "启用" : "禁用"}');
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
    _debugMode = false;
    _logLevel = LogLevel.info;
    _performanceMetricsEnabled = false;
    _showPlaybackProgress = true;
    _audioQuality = AudioQuality.medium;
    
    print('🔄 [TTS Config] 配置已重置为默认值');
  }
  
  /// 获取当前配置摘要
  Map<String, dynamic> getConfigSummary() {
    return {
      'playbackStrategy': _playbackStrategy.name,
      'cacheEnabled': _cacheEnabled,
      'preloadEnabled': _preloadEnabled,
      'debugMode': _debugMode,
      'logLevel': _logLevel.name,
      'performanceMetricsEnabled': _performanceMetricsEnabled,
      'showPlaybackProgress': _showPlaybackProgress,
      'audioQuality': _audioQuality.name,
      'sampleRate': sampleRate,
      'audioFormat': audioFormat,
      'maxCacheFiles': maxCacheFiles,
      'cacheExpirationHours': cacheExpirationHours,
    };
  }
}