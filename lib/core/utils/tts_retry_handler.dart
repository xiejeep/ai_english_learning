import 'dart:async';
import 'dart:io';
import 'tts_logger.dart';
import 'tts_performance_monitor.dart';

/// TTS重试处理器
class TTSRetryHandler {
  static const int _defaultMaxRetries = 3;
  static const Duration _defaultRetryDelay = Duration(milliseconds: 500);
  static const Duration _maxRetryDelay = Duration(seconds: 5);
  
  /// 执行带重试的操作
  static Future<T> executeWithRetry<T>(
    String operationName,
    Future<T> Function() operation, {
    int maxRetries = _defaultMaxRetries,
    Duration baseDelay = _defaultRetryDelay,
    bool useExponentialBackoff = true,
    bool Function(dynamic error)? shouldRetry,
  }) async {
    TTSPerformanceMonitor.startTimer('retry_$operationName');
    TTSPerformanceMonitor.incrementCounter('retry_attempts_$operationName');
    
    for (int attempt = 1; attempt <= maxRetries + 1; attempt++) {
      try {
        final result = await operation();
        
        if (attempt > 1) {
          TTSLogger.success('$operationName 在第 $attempt 次尝试后成功');
          TTSPerformanceMonitor.recordEvent('retry_success', data: {
            'operation': operationName,
            'attempt': attempt,
          });
        }
        
        return result;
      } catch (error) {
        final isLastAttempt = attempt > maxRetries;
        
        // 检查是否应该重试
        if (isLastAttempt || (shouldRetry != null && !shouldRetry(error))) {
          TTSLogger.error('$operationName 最终失败: $error');
          TTSPerformanceMonitor.recordEvent('retry_final_failure', data: {
            'operation': operationName,
            'attempts': attempt,
            'error': error.toString(),
          });
          rethrow;
        }
        
        // 计算延迟时间
        Duration delay = baseDelay;
        if (useExponentialBackoff) {
          delay = Duration(
            milliseconds: (baseDelay.inMilliseconds * (1 << (attempt - 1)))
                .clamp(baseDelay.inMilliseconds, _maxRetryDelay.inMilliseconds),
          );
        }
        
        TTSLogger.warning(
          '$operationName 第 $attempt 次尝试失败: $error, '
          '${delay.inMilliseconds}ms 后重试'
        );
        
        TTSPerformanceMonitor.recordEvent('retry_attempt', data: {
          'operation': operationName,
          'attempt': attempt,
          'error': error.toString(),
          'delay_ms': delay.inMilliseconds,
        });
        
        await Future.delayed(delay);
      }
    }
    
    // 这行代码理论上不会执行到
    throw StateError('Unexpected end of retry loop');
  }
  
  /// 检查错误是否可重试
  static bool isRetryableError(dynamic error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    
    final errorString = error.toString().toLowerCase();
    
    // 网络相关错误
    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable')) {
      return true;
    }
    
    // 临时文件系统错误
    if (errorString.contains('permission denied') ||
        errorString.contains('file not found') ||
        errorString.contains('directory not found')) {
      return true;
    }
    
    // 音频播放器相关错误
    if (errorString.contains('player') ||
        errorString.contains('audio') ||
        errorString.contains('source')) {
      return true;
    }
    
    return false;
  }
  
  /// 执行带降级策略的操作
  static Future<T> executeWithFallback<T>(
    String operationName,
    Future<T> Function() primaryOperation,
    Future<T> Function() fallbackOperation, {
    int maxRetries = _defaultMaxRetries,
    Duration baseDelay = _defaultRetryDelay,
  }) async {
    try {
      return await executeWithRetry(
        operationName,
        primaryOperation,
        maxRetries: maxRetries,
        baseDelay: baseDelay,
        shouldRetry: isRetryableError,
      );
    } catch (error) {
      TTSLogger.warning('$operationName 主要操作失败，尝试降级策略: $error');
      TTSPerformanceMonitor.recordEvent('fallback_triggered', data: {
        'operation': operationName,
        'primary_error': error.toString(),
      });
      
      try {
        final result = await fallbackOperation();
        TTSLogger.success('$operationName 降级策略成功');
        TTSPerformanceMonitor.recordEvent('fallback_success', data: {
          'operation': operationName,
        });
        return result;
      } catch (fallbackError) {
        TTSLogger.error('$operationName 降级策略也失败: $fallbackError');
        TTSPerformanceMonitor.recordEvent('fallback_failure', data: {
          'operation': operationName,
          'fallback_error': fallbackError.toString(),
        });
        rethrow;
      }
    } finally {
      TTSPerformanceMonitor.endTimer('retry_$operationName');
    }
  }
  
  /// 创建超时包装器
  static Future<T> withTimeout<T>(
    String operationName,
    Future<T> Function() operation,
    Duration timeout,
  ) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      TTSLogger.error('$operationName 操作超时 (${timeout.inSeconds}s)');
      TTSPerformanceMonitor.recordEvent('operation_timeout', data: {
        'operation': operationName,
        'timeout_seconds': timeout.inSeconds,
      });
      rethrow;
    }
  }
  
  /// 批量重试操作
  static Future<List<T>> executeMultipleWithRetry<T>(
    String operationName,
    List<Future<T> Function()> operations, {
    int maxRetries = _defaultMaxRetries,
    Duration baseDelay = _defaultRetryDelay,
    bool failFast = false,
  }) async {
    final results = <T>[];
    final errors = <dynamic>[];
    
    for (int i = 0; i < operations.length; i++) {
      try {
        final result = await executeWithRetry(
          '${operationName}_$i',
          operations[i],
          maxRetries: maxRetries,
          baseDelay: baseDelay,
          shouldRetry: isRetryableError,
        );
        results.add(result);
      } catch (error) {
        errors.add(error);
        if (failFast) {
          TTSLogger.error('$operationName 批量操作快速失败: $error');
          rethrow;
        }
      }
    }
    
    if (errors.isNotEmpty && results.isEmpty) {
      TTSLogger.error('$operationName 所有批量操作都失败');
      throw Exception('All operations failed: ${errors.join(', ')}');
    }
    
    if (errors.isNotEmpty) {
      TTSLogger.warning(
        '$operationName 批量操作部分失败: ${errors.length}/${operations.length}'
      );
    }
    
    return results;
  }
}