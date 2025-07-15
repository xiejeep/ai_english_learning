import '../config/tts_config.dart';
import 'playlist_tts_service.dart';

/// TTS音频块缓冲合并功能使用示例
/// 
/// 这个示例展示了如何配置和使用新的音频块合并功能来减少播放卡顿
class TTSBufferingExample {
  late PlaylistTTSService _ttsService;
  late TTSConfig _config;
  
  /// 初始化服务
  Future<void> initialize() async {
    _ttsService = PlaylistTTSService();
    _config = TTSConfig.instance;
    
    // 配置音频块合并参数
    await _setupBufferingConfig();
    
    // 初始化TTS服务
    await _ttsService.initialize();
    
    // 设置回调
    _ttsService.setCallbacks(
      onPlaybackStarted: () => print('🎵 播放开始'),
      onPlaybackCompleted: () => print('✅ 播放完成'),
      onError: (error) => print('❌ 播放错误: $error'),
    );
  }
  
  /// 配置缓冲参数
  Future<void> _setupBufferingConfig() async {
    // 启用音频块合并（默认已启用）
    _config.setChunkMergingEnabled(true);
    
    // 设置每个段包含5个音频块（可以根据需要调整）
    _config.setChunksPerSegment(5);
    
    // 启用第一段快速播放（减少初始延迟）
    _config.setFastFirstSegment(true);
    
    print('🔧 缓冲配置已设置:');
    print('   - 音频块合并: ${_config.chunkMergingEnabled}');
    print('   - 每段音频块数: ${_config.chunksPerSegment}');
    print('   - 第一段快速播放: ${_config.fastFirstSegment}');
  }
  
  /// 模拟处理TTS音频流
  Future<void> simulateTTSStream(String messageId, List<String> audioChunks) async {
    print('🚀 开始处理TTS音频流: $messageId');
    print('📦 总共 ${audioChunks.length} 个音频块');
    
    // 逐个处理音频块
    for (int i = 0; i < audioChunks.length; i++) {
      await _ttsService.processTTSChunk(messageId, audioChunks[i]);
      
      // 模拟网络延迟
      await Future.delayed(Duration(milliseconds: 100));
      
      print('📥 已处理音频块 ${i + 1}/${audioChunks.length}');
    }
    
    // 完成消息处理
    await _ttsService.finishTTSMessage(messageId);
    print('🎯 TTS音频流处理完成');
  }
  
  /// 动态调整缓冲参数
  void adjustBufferingSettings({
    int? chunksPerSegment,
    bool? enableMerging,
    bool? fastFirstSegment,
  }) {
    if (chunksPerSegment != null) {
      _config.setChunksPerSegment(chunksPerSegment);
    }
    
    if (enableMerging != null) {
      _config.setChunkMergingEnabled(enableMerging);
    }
    
    if (fastFirstSegment != null) {
      _config.setFastFirstSegment(fastFirstSegment);
    }
    
    print('⚙️ 缓冲参数已调整');
    _printCurrentConfig();
  }
  
  /// 打印当前配置
  void _printCurrentConfig() {
    final config = _config.getConfigSummary();
    print('📋 当前TTS配置:');
    config.forEach((key, value) {
      print('   $key: $value');
    });
  }
  
  /// 获取播放状态
  Map<String, dynamic> getPlaybackStatus() {
    return {
      'isPlaying': _ttsService.isPlaying,
      'isInitialized': _ttsService.isInitialized,
      'currentMessageId': _ttsService.currentMessageId,
      'chunkCount': _ttsService.chunkCount,
      'mergingEnabled': _config.chunkMergingEnabled,
      'chunksPerSegment': _config.chunksPerSegment,
    };
  }
  
  /// 清理资源
  Future<void> dispose() async {
    await _ttsService.dispose();
    print('🧹 TTS服务已清理');
  }
}

/// 使用示例
void main() async {
  final example = TTSBufferingExample();
  
  try {
    // 初始化
    await example.initialize();
    
    // 模拟音频块数据（实际使用中这些是base64编码的音频数据）
    final audioChunks = List.generate(12, (i) => 'audio_chunk_$i');
    
    // 处理TTS音频流
    await example.simulateTTSStream('message_001', audioChunks);
    
    // 打印播放状态
    print('📊 播放状态: ${example.getPlaybackStatus()}');
    
    // 可以动态调整参数
    example.adjustBufferingSettings(
      chunksPerSegment: 3, // 改为每3个块合并一次
      fastFirstSegment: false, // 禁用第一段快速播放
    );
    
  } finally {
    // 清理资源
    await example.dispose();
  }
}