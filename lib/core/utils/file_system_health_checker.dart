import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'tts_logger.dart';

/// 文件系统健康检查工具
class FileSystemHealthChecker {
  static const String _healthCheckFileName = 'tts_health_check.tmp';
  static const String _testContent = 'health_check_test';
  
  /// 检查存储系统健康状态
  static Future<bool> checkStorageHealth() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final testFile = File('${tempDir.path}/$_healthCheckFileName');
      
      // 写入测试
      await testFile.writeAsString(_testContent);
      TTSLogger.debug('健康检查：写入测试文件成功');
      
      // 读取测试
      final content = await testFile.readAsString();
      TTSLogger.debug('健康检查：读取测试文件成功');
      
      // 验证内容
      final isContentValid = content == _testContent;
      
      // 清理测试文件
      try {
        await testFile.delete();
        TTSLogger.debug('健康检查：清理测试文件成功');
      } catch (e) {
        TTSLogger.warning('健康检查：清理测试文件失败: $e');
      }
      
      if (isContentValid) {
        TTSLogger.success('存储系统健康检查通过');
      } else {
        TTSLogger.error('存储系统健康检查失败：内容不匹配');
      }
      
      return isContentValid;
    } catch (e) {
      TTSLogger.error('存储系统健康检查失败: $e');
      return false;
    }
  }
  
  /// 检查指定目录的可用性
  static Future<bool> checkDirectoryHealth(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      
      // 检查目录是否存在
      if (!await dir.exists()) {
        TTSLogger.warning('目录不存在: $dirPath');
        return false;
      }
      
      // 检查读写权限
      final testFile = File('$dirPath/$_healthCheckFileName');
      await testFile.writeAsString(_testContent);
      final content = await testFile.readAsString();
      await testFile.delete();
      
      final isHealthy = content == _testContent;
      if (isHealthy) {
        TTSLogger.debug('目录健康检查通过: $dirPath');
      } else {
        TTSLogger.error('目录健康检查失败: $dirPath');
      }
      
      return isHealthy;
    } catch (e) {
      TTSLogger.error('目录健康检查失败 $dirPath: $e');
      return false;
    }
  }
  
  /// 获取存储空间信息
  static Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final stat = await tempDir.stat();
      
      return {
        'path': tempDir.path,
        'exists': await tempDir.exists(),
        'modified': stat.modified.toIso8601String(),
        'accessible': await checkDirectoryHealth(tempDir.path),
      };
    } catch (e) {
      TTSLogger.error('获取存储信息失败: $e');
      return {
        'error': e.toString(),
        'accessible': false,
      };
    }
  }
  
  /// 清理过期的健康检查文件
  static Future<void> cleanupHealthCheckFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final files = await tempDir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.contains(_healthCheckFileName)) {
          try {
            await file.delete();
            TTSLogger.debug('清理健康检查文件: ${file.path}');
          } catch (e) {
            TTSLogger.warning('清理健康检查文件失败 ${file.path}: $e');
          }
        }
      }
    } catch (e) {
      TTSLogger.error('清理健康检查文件失败: $e');
    }
  }
}