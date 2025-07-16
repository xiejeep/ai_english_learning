import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// TTS音频缓存服务
/// 负责管理TTS音频文件的本地缓存，避免重复请求相同文本的音频
class TTSCacheService {
  static TTSCacheService? _instance;
  static TTSCacheService get instance => _instance ??= TTSCacheService._();
  
  TTSCacheService._();
  
  /// 缓存目录
  Directory? _cacheDir;
  
  /// 缓存索引文件，记录文本哈希与文件路径的映射
  File? _indexFile;
  
  /// 内存中的缓存索引
  Map<String, String> _cacheIndex = {};
  
  /// 最大缓存文件数量
  static const int maxCacheFiles = 100;
  
  /// 最大缓存大小（MB）
  static const int maxCacheSizeMB = 50;
  
  /// 初始化缓存服务
  Future<void> initialize() async {
    try {
      print('🔄 开始初始化TTS缓存服务...');
      
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      print('📁 应用文档目录: ${appDir.path}');
      
      // 验证应用目录可访问性
      if (!await appDir.exists()) {
        throw Exception('应用文档目录不存在: ${appDir.path}');
      }
      
      // 创建TTS缓存目录
      _cacheDir = Directory(path.join(appDir.path, 'tts_cache'));
      print('📁 缓存目录路径: ${_cacheDir!.path}');
      
      if (!await _cacheDir!.exists()) {
        print('📁 创建缓存目录...');
        await _cacheDir!.create(recursive: true);
        
        // 验证目录创建成功
        if (!await _cacheDir!.exists()) {
          throw Exception('缓存目录创建失败: ${_cacheDir!.path}');
        }
        print('✅ 缓存目录创建成功');
      } else {
        print('✅ 缓存目录已存在');
      }
      
      // 测试目录权限
      await _testDirectoryPermissions();
      
      // 初始化索引文件
      _indexFile = File(path.join(_cacheDir!.path, 'cache_index.json'));
      print('📄 索引文件路径: ${_indexFile!.path}');
      
      // 加载现有的缓存索引
      await _loadCacheIndex();
      
      // 清理过期或无效的缓存
      await _cleanupCache();
      
      // 获取最终统计信息
      final stats = await getCacheStats();
      
      print('✅ TTS缓存服务初始化完成');
      print('📊 缓存目录: ${_cacheDir!.path}');
      print('📊 缓存文件数量: ${stats['fileCount']}');
      print('📊 缓存总大小: ${stats['totalSizeMB'].toStringAsFixed(2)} MB');
      print('📊 最大文件数: $maxCacheFiles');
      print('📊 最大大小: $maxCacheSizeMB MB');
      
    } catch (e, stackTrace) {
      print('❌ TTS缓存服务初始化失败: $e');
      print('📍 错误堆栈: $stackTrace');
      
      // 尝试基本的错误恢复
      try {
        await _attemptErrorRecovery();
      } catch (recoveryError) {
        print('❌ 错误恢复失败: $recoveryError');
      }
      
      rethrow;
    }
  }
  
  /// 测试目录权限
  Future<void> _testDirectoryPermissions() async {
    try {
      final testFile = File(path.join(_cacheDir!.path, 'permission_test.tmp'));
      
      // 测试写入
      await testFile.writeAsString('test');
      print('✅ 缓存目录写入权限正常');
      
      // 测试读取
      final content = await testFile.readAsString();
      if (content != 'test') {
        throw Exception('读取测试失败');
      }
      print('✅ 缓存目录读取权限正常');
      
      // 测试删除
      await testFile.delete();
      print('✅ 缓存目录删除权限正常');
      
    } catch (e) {
      throw Exception('缓存目录权限测试失败: $e');
    }
  }
  
  /// 尝试错误恢复
  Future<void> _attemptErrorRecovery() async {
    print('🔧 尝试错误恢复...');
    
    try {
      // 重置内部状态
      _cacheIndex.clear();
      _cacheDir = null;
      _indexFile = null;
      
      // 尝试重新获取应用目录
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory(path.join(appDir.path, 'tts_cache'));
      
      // 强制创建目录
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
      }
      await _cacheDir!.create(recursive: true);
      
      // 创建新的索引文件
      _indexFile = File(path.join(_cacheDir!.path, 'cache_index.json'));
      await _indexFile!.writeAsString('{}');
      
      print('✅ 错误恢复成功');
    } catch (e) {
      print('❌ 错误恢复失败: $e');
      rethrow;
    }
  }
  
  /// 生成文本的哈希值作为缓存键
  String _generateCacheKey(String text) {
    final bytes = utf8.encode(text.trim().toLowerCase());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// 检查是否存在缓存
  Future<bool> hasCachedAudio(String text) async {
    if (_cacheDir == null) return false;
    
    final cacheKey = _generateCacheKey(text);
    
    // 检查内存索引
    if (!_cacheIndex.containsKey(cacheKey)) {
      return false;
    }
    
    // 检查文件是否实际存在
    final filePath = _cacheIndex[cacheKey]!;
    final file = File(filePath);
    
    if (await file.exists()) {
      return true;
    } else {
      // 文件不存在，从索引中移除
      _cacheIndex.remove(cacheKey);
      await _saveCacheIndex();
      return false;
    }
  }
  
  /// 获取缓存的音频文件路径
  Future<String?> getCachedAudioPath(String text) async {
    if (!await hasCachedAudio(text)) {
      return null;
    }
    
    final cacheKey = _generateCacheKey(text);
    final filePath = _cacheIndex[cacheKey]!;
    
    // 更新文件的访问时间（用于LRU清理）
    final file = File(filePath);
    try {
      await file.setLastAccessed(DateTime.now());
    } catch (e) {
      print('⚠️ 更新文件访问时间失败: $e');
    }
    
    print('🎯 使用缓存音频: ${path.basename(filePath)}');
    return filePath;
  }
  
  /// 缓存音频文件
  Future<String> cacheAudioFile(String text, String tempFilePath) async {
    if (_cacheDir == null) {
      throw Exception('TTS缓存服务未初始化');
    }
    
    final cacheKey = _generateCacheKey(text);
    
    // 生成缓存文件名
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final cacheFileName = '${cacheKey}_$timestamp.mp3';
    final cacheFilePath = path.join(_cacheDir!.path, cacheFileName);
    
    try {
      // 复制临时文件到缓存目录
      final tempFile = File(tempFilePath);
      final cacheFile = File(cacheFilePath);
      
      await tempFile.copy(cacheFilePath);
      
      // 验证缓存文件
      if (await cacheFile.exists()) {
        final fileSize = await cacheFile.length();
        print('💾 音频已缓存: ${path.basename(cacheFilePath)}, 大小: $fileSize 字节');
        
        // 更新缓存索引
        _cacheIndex[cacheKey] = cacheFilePath;
        await _saveCacheIndex();
        
        // 检查缓存大小，必要时清理
        await _checkCacheSizeAndCleanup();
        
        return cacheFilePath;
      } else {
        throw Exception('缓存文件创建失败');
      }
    } catch (e) {
      print('❌ 缓存音频文件失败: $e');
      rethrow;
    }
  }
  
  /// 加载缓存索引
  Future<void> _loadCacheIndex() async {
    if (_indexFile == null || !await _indexFile!.exists()) {
      _cacheIndex = {};
      return;
    }
    
    try {
      final content = await _indexFile!.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      _cacheIndex = data.cast<String, String>();
      print('📖 加载缓存索引: ${_cacheIndex.length} 个条目');
    } catch (e) {
      print('⚠️ 加载缓存索引失败: $e，重新创建索引');
      _cacheIndex = {};
    }
  }
  
  /// 保存缓存索引
  Future<void> _saveCacheIndex() async {
    if (_indexFile == null) return;
    
    try {
      final content = jsonEncode(_cacheIndex);
      await _indexFile!.writeAsString(content);
    } catch (e) {
      print('❌ 保存缓存索引失败: $e');
    }
  }
  
  /// 清理缓存
  Future<void> _cleanupCache() async {
    if (_cacheDir == null) return;
    
    try {
      // 获取缓存目录中的所有文件
      final files = await _cacheDir!.list().toList();
      final audioFiles = files
          .where((entity) => entity is File && entity.path.endsWith('.mp3'))
          .cast<File>()
          .toList();
      
      // 检查索引中的文件是否实际存在
      final keysToRemove = <String>[];
      for (final entry in _cacheIndex.entries) {
        final file = File(entry.value);
        if (!await file.exists()) {
          keysToRemove.add(entry.key);
        }
      }
      
      // 移除无效的索引条目
      for (final key in keysToRemove) {
        _cacheIndex.remove(key);
      }
      
      // 删除没有在索引中的孤立文件
      final indexedPaths = _cacheIndex.values.toSet();
      for (final file in audioFiles) {
        if (!indexedPaths.contains(file.path)) {
          try {
            await file.delete();
            print('🗑️ 删除孤立缓存文件: ${path.basename(file.path)}');
          } catch (e) {
            print('⚠️ 删除孤立文件失败: $e');
          }
        }
      }
      
      // 保存更新后的索引
      await _saveCacheIndex();
      
      print('🧹 缓存清理完成，有效文件数: ${_cacheIndex.length}');
    } catch (e) {
      print('❌ 缓存清理失败: $e');
    }
  }
  
  /// 检查缓存大小并清理
  Future<void> _checkCacheSizeAndCleanup() async {
    if (_cacheDir == null) return;
    
    try {
      // 检查文件数量
      if (_cacheIndex.length > maxCacheFiles) {
        await _cleanupByCount();
      }
      
      // 检查缓存大小
      final totalSize = await _calculateCacheSize();
      const maxSizeBytes = maxCacheSizeMB * 1024 * 1024;
      
      if (totalSize > maxSizeBytes) {
        await _cleanupBySize(maxSizeBytes);
      }
    } catch (e) {
      print('❌ 检查缓存大小失败: $e');
    }
  }
  
  /// 按数量清理缓存（LRU）
  Future<void> _cleanupByCount() async {
    final targetCount = (maxCacheFiles * 0.8).round(); // 清理到80%
    final filesToRemove = _cacheIndex.length - targetCount;
    
    if (filesToRemove <= 0) return;
    
    // 获取文件的最后访问时间
    final fileStats = <String, DateTime>{};
    for (final entry in _cacheIndex.entries) {
      try {
        final file = File(entry.value);
        final stat = await file.stat();
        fileStats[entry.key] = stat.accessed;
      } catch (e) {
        // 文件不存在或无法访问，标记为最早时间
        fileStats[entry.key] = DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    
    // 按访问时间排序，删除最旧的文件
    final sortedKeys = fileStats.keys.toList()
      ..sort((a, b) => fileStats[a]!.compareTo(fileStats[b]!));
    
    for (int i = 0; i < filesToRemove; i++) {
      final key = sortedKeys[i];
      await _removeCacheFile(key);
    }
    
    print('🗑️ 按数量清理缓存: 删除了 $filesToRemove 个文件');
  }
  
  /// 按大小清理缓存
  Future<void> _cleanupBySize(int maxSizeBytes) async {
    final targetSize = (maxSizeBytes * 0.8).round(); // 清理到80%
    
    // 获取文件大小和访问时间
    final fileInfo = <String, Map<String, dynamic>>{};
    for (final entry in _cacheIndex.entries) {
      try {
        final file = File(entry.value);
        final stat = await file.stat();
        fileInfo[entry.key] = {
          'size': stat.size,
          'accessed': stat.accessed,
        };
      } catch (e) {
        // 文件不存在或无法访问
        fileInfo[entry.key] = {
          'size': 0,
          'accessed': DateTime.fromMillisecondsSinceEpoch(0),
        };
      }
    }
    
    // 按访问时间排序
    final sortedKeys = fileInfo.keys.toList()
      ..sort((a, b) => fileInfo[a]!['accessed'].compareTo(fileInfo[b]!['accessed']));
    
    int currentSize = fileInfo.values.fold(0, (sum, info) => sum + (info['size'] as int));
    int removedCount = 0;
    
    // 删除最旧的文件直到达到目标大小
    for (final key in sortedKeys) {
      if (currentSize <= targetSize) break;
      
      final size = fileInfo[key]!['size'] as int;
      await _removeCacheFile(key);
      currentSize -= size;
      removedCount++;
    }
    
    print('🗑️ 按大小清理缓存: 删除了 $removedCount 个文件，释放了 ${(currentSize / 1024 / 1024).toStringAsFixed(2)} MB');
  }
  
  /// 删除缓存文件
  Future<void> _removeCacheFile(String cacheKey) async {
    final filePath = _cacheIndex[cacheKey];
    if (filePath != null) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
        _cacheIndex.remove(cacheKey);
      } catch (e) {
        print('⚠️ 删除缓存文件失败: $e');
      }
    }
  }
  
  /// 计算缓存总大小
  Future<int> _calculateCacheSize() async {
    int totalSize = 0;
    
    for (final filePath in _cacheIndex.values) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      } catch (e) {
        // 忽略无法访问的文件
      }
    }
    
    return totalSize;
  }
  
  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    final fileCount = _cacheIndex.length;
    final totalSize = await _calculateCacheSize();
    final sizeMB = totalSize / 1024 / 1024;
    
    return {
      'fileCount': fileCount,
      'totalSizeBytes': totalSize,
      'totalSizeMB': sizeMB,
      'maxFiles': maxCacheFiles,
      'maxSizeMB': maxCacheSizeMB,
      'cacheDir': _cacheDir?.path ?? 'Not initialized',
    };
  }
  
  /// 清空所有缓存
  Future<void> clearAllCache() async {
    if (_cacheDir == null) return;
    
    try {
      // 删除所有缓存文件
      for (final filePath in _cacheIndex.values) {
        try {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          print('⚠️ 删除缓存文件失败: $e');
        }
      }
      
      // 清空索引
      _cacheIndex.clear();
      await _saveCacheIndex();
      
      print('🗑️ 已清空所有TTS缓存');
    } catch (e) {
      print('❌ 清空缓存失败: $e');
    }
  }
}