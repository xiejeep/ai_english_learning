import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/tts_cache_service.dart';

/// TTS缓存诊断工具
/// 用于诊断和修复缓存相关问题
class TTSCacheDiagnostics {
  /// 执行完整的缓存诊断
  static Future<Map<String, dynamic>> runFullDiagnostics() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'checks': <String, dynamic>{},
      'issues': <String>[],
      'recommendations': <String>[],
    };

    try {
      // 1. 检查应用文档目录
      final appDirCheck = await _checkApplicationDirectory();
      results['checks']['applicationDirectory'] = appDirCheck;
      if (!appDirCheck['success']) {
        results['issues'].add('应用文档目录不可访问');
        results['recommendations'].add('检查应用权限设置');
      }

      // 2. 检查缓存目录
      final cacheDirCheck = await _checkCacheDirectory();
      results['checks']['cacheDirectory'] = cacheDirCheck;
      if (!cacheDirCheck['success']) {
        results['issues'].add('缓存目录创建或访问失败');
        results['recommendations'].add('尝试重新创建缓存目录');
      }

      // 3. 检查缓存索引文件
      final indexCheck = await _checkCacheIndex();
      results['checks']['cacheIndex'] = indexCheck;
      if (!indexCheck['success']) {
        results['issues'].add('缓存索引文件损坏或不存在');
        results['recommendations'].add('重建缓存索引');
      }

      // 4. 检查缓存文件完整性
      final filesCheck = await _checkCacheFiles();
      results['checks']['cacheFiles'] = filesCheck;
      if (filesCheck['orphanedFiles'] > 0) {
        results['issues'].add('发现孤立的缓存文件');
        results['recommendations'].add('清理孤立文件');
      }

      // 5. 检查权限
      final permissionsCheck = await _checkPermissions();
      results['checks']['permissions'] = permissionsCheck;
      if (!permissionsCheck['success']) {
        results['issues'].add('缓存目录权限不足');
        results['recommendations'].add('检查文件系统权限');
      }

      // 6. 性能测试
      final performanceCheck = await _performanceTest();
      results['checks']['performance'] = performanceCheck;

      results['summary'] = {
        'totalIssues': (results['issues'] as List).length,
        'isHealthy': (results['issues'] as List).isEmpty,
        'cacheEnabled': cacheDirCheck['success'] && indexCheck['success'],
      };

    } catch (e) {
      results['error'] = e.toString();
      results['issues'].add('诊断过程中发生错误: $e');
    }

    return results;
  }

  /// 检查应用文档目录
  static Future<Map<String, dynamic>> _checkApplicationDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final exists = await appDir.exists();
      final stat = exists ? await appDir.stat() : null;

      return {
        'success': exists,
        'path': appDir.path,
        'exists': exists,
        'readable': exists,
        'writable': exists,
        'size': stat?.size ?? 0,
        'modified': stat?.modified.toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 检查缓存目录
  static Future<Map<String, dynamic>> _checkCacheDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'tts_cache'));
      
      bool exists = await cacheDir.exists();
      
      // 如果不存在，尝试创建
      if (!exists) {
        await cacheDir.create(recursive: true);
        exists = await cacheDir.exists();
      }

      final stat = exists ? await cacheDir.stat() : null;
      final files = exists ? await cacheDir.list().length : 0;

      return {
        'success': exists,
        'path': cacheDir.path,
        'exists': exists,
        'fileCount': files,
        'size': stat?.size ?? 0,
        'modified': stat?.modified.toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 检查缓存索引文件
  static Future<Map<String, dynamic>> _checkCacheIndex() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'tts_cache'));
      final indexFile = File(path.join(cacheDir.path, 'cache_index.json'));
      
      final exists = await indexFile.exists();
      Map<String, dynamic> indexData = {};
      int entryCount = 0;
      bool isValid = false;

      if (exists) {
        try {
          final content = await indexFile.readAsString();
          indexData = jsonDecode(content) as Map<String, dynamic>;
          entryCount = indexData.length;
          isValid = true;
        } catch (e) {
          // 索引文件损坏，尝试重建
          await indexFile.writeAsString('{}');
          isValid = false;
        }
      } else {
        // 创建新的索引文件
        await indexFile.writeAsString('{}');
        isValid = true;
      }

      final stat = await indexFile.stat();

      return {
        'success': isValid,
        'exists': exists,
        'path': indexFile.path,
        'entryCount': entryCount,
        'size': stat.size,
        'isValid': isValid,
        'modified': stat.modified.toIso8601String(),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 检查缓存文件完整性
  static Future<Map<String, dynamic>> _checkCacheFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'tts_cache'));
      
      if (!await cacheDir.exists()) {
        return {
          'success': false,
          'error': '缓存目录不存在',
        };
      }

      // 获取所有音频文件
      final files = await cacheDir.list().where((entity) => 
        entity is File && entity.path.endsWith('.mp3')).cast<File>().toList();
      
      // 读取索引
      final indexFile = File(path.join(cacheDir.path, 'cache_index.json'));
      Map<String, String> index = {};
      
      if (await indexFile.exists()) {
        try {
          final content = await indexFile.readAsString();
          final data = jsonDecode(content) as Map<String, dynamic>;
          index = data.cast<String, String>();
        } catch (e) {
          // 索引损坏
        }
      }

      // 检查文件完整性
      int validFiles = 0;
      int corruptedFiles = 0;
      int orphanedFiles = 0;
      int totalSize = 0;

      final indexedPaths = index.values.toSet();

      for (final file in files) {
        try {
          final stat = await file.stat();
          totalSize += stat.size;

          if (stat.size < 1024) {
            corruptedFiles++;
          } else {
            validFiles++;
          }

          if (!indexedPaths.contains(file.path)) {
            orphanedFiles++;
          }
        } catch (e) {
          corruptedFiles++;
        }
      }

      return {
        'success': true,
        'totalFiles': files.length,
        'validFiles': validFiles,
        'corruptedFiles': corruptedFiles,
        'orphanedFiles': orphanedFiles,
        'indexedFiles': index.length,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / 1024 / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 检查权限
  static Future<Map<String, dynamic>> _checkPermissions() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'tts_cache'));
      
      // 确保目录存在
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // 测试写入权限
      final testFile = File(path.join(cacheDir.path, 'permission_test.tmp'));
      bool canWrite = false;
      bool canRead = false;
      bool canDelete = false;

      try {
        await testFile.writeAsString('test');
        canWrite = true;
        
        await testFile.readAsString();
        canRead = true;
        
        await testFile.delete();
        canDelete = true;
      } catch (e) {
        // 权限不足
        try {
          if (await testFile.exists()) {
            await testFile.delete();
          }
        } catch (_) {}
      }

      return {
        'success': canWrite && canRead && canDelete,
        'canWrite': canWrite,
        'canRead': canRead,
        'canDelete': canDelete,
        'path': cacheDir.path,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 性能测试
  static Future<Map<String, dynamic>> _performanceTest() async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // 测试缓存服务初始化时间
      final initStart = stopwatch.elapsedMilliseconds;
      await TTSCacheService.instance.initialize();
      final initTime = stopwatch.elapsedMilliseconds - initStart;
      
      // 测试缓存查找时间
      final lookupStart = stopwatch.elapsedMilliseconds;
      await TTSCacheService.instance.hasCachedAudio('test_text_for_performance');
      final lookupTime = stopwatch.elapsedMilliseconds - lookupStart;
      
      // 获取缓存统计
      final stats = await TTSCacheService.instance.getCacheStats();
      
      stopwatch.stop();

      return {
        'success': true,
        'initTimeMs': initTime,
        'lookupTimeMs': lookupTime,
        'totalTimeMs': stopwatch.elapsedMilliseconds,
        'cacheStats': stats,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// 修复缓存问题
  static Future<Map<String, dynamic>> repairCache() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'actions': <String>[],
      'success': false,
    };

    try {
      // 1. 重新创建缓存目录
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'tts_cache'));
      
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
        results['actions'].add('创建缓存目录');
      }

      // 2. 重建缓存索引
      final indexFile = File(path.join(cacheDir.path, 'cache_index.json'));
      await indexFile.writeAsString('{}');
      results['actions'].add('重建缓存索引');

      // 3. 清理损坏的文件
      final files = await cacheDir.list().where((entity) => 
        entity is File && entity.path.endsWith('.mp3')).cast<File>().toList();
      
      int cleanedFiles = 0;
      for (final file in files) {
        try {
          final stat = await file.stat();
          if (stat.size < 1024) {
            await file.delete();
            cleanedFiles++;
          }
        } catch (e) {
          try {
            await file.delete();
            cleanedFiles++;
          } catch (_) {}
        }
      }
      
      if (cleanedFiles > 0) {
        results['actions'].add('清理了 $cleanedFiles 个损坏文件');
      }

      // 4. 重新初始化缓存服务
      await TTSCacheService.instance.initialize();
      results['actions'].add('重新初始化缓存服务');

      results['success'] = true;
    } catch (e) {
      results['error'] = e.toString();
    }

    return results;
  }

  /// 生成诊断报告
  static String generateReport(Map<String, dynamic> diagnostics) {
    final buffer = StringBuffer();
    
    buffer.writeln('=== TTS缓存诊断报告 ===');
    buffer.writeln('时间: ${diagnostics['timestamp']}');
    buffer.writeln();
    
    final summary = diagnostics['summary'] as Map<String, dynamic>?;
    if (summary != null) {
      buffer.writeln('总体状态: ${summary['isHealthy'] ? '健康' : '存在问题'}');
      buffer.writeln('问题数量: ${summary['totalIssues']}');
      buffer.writeln('缓存可用: ${summary['cacheEnabled'] ? '是' : '否'}');
      buffer.writeln();
    }
    
    final issues = diagnostics['issues'] as List?;
    if (issues != null && issues.isNotEmpty) {
      buffer.writeln('发现的问题:');
      for (final issue in issues) {
        buffer.writeln('  • $issue');
      }
      buffer.writeln();
    }
    
    final recommendations = diagnostics['recommendations'] as List?;
    if (recommendations != null && recommendations.isNotEmpty) {
      buffer.writeln('建议措施:');
      for (final rec in recommendations) {
        buffer.writeln('  • $rec');
      }
      buffer.writeln();
    }
    
    final checks = diagnostics['checks'] as Map<String, dynamic>?;
    if (checks != null) {
      buffer.writeln('详细检查结果:');
      checks.forEach((key, value) {
        buffer.writeln('  $key: ${value['success'] ? '✅' : '❌'}');
        if (value['error'] != null) {
          buffer.writeln('    错误: ${value['error']}');
        }
      });
    }
    
    return buffer.toString();
  }
}