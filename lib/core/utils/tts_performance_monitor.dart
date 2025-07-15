import 'dart:async';
import 'dart:collection';
import 'tts_logger.dart';

/// TTS性能监控工具
class TTSPerformanceMonitor {
  static final Map<String, Stopwatch> _timers = {};
  static final Map<String, Queue<int>> _metrics = {};
  static final Map<String, int> _counters = {};
  
  // 配置参数
  static const int _maxMetricHistory = 100;
  static const Duration _reportInterval = Duration(minutes: 5);
  
  static Timer? _reportTimer;
  static bool _isEnabled = true;
  
  /// 启用性能监控
  static void enable() {
    _isEnabled = true;
    _startPeriodicReporting();
    TTSLogger.config('性能监控已启用');
  }
  
  /// 禁用性能监控
  static void disable() {
    _isEnabled = false;
    _stopPeriodicReporting();
    TTSLogger.config('性能监控已禁用');
  }
  
  /// 开始计时
  static void startTimer(String operation) {
    if (!_isEnabled) return;
    
    _timers[operation] = Stopwatch()..start();
    TTSLogger.debug('开始计时: $operation');
  }
  
  /// 结束计时并记录
  static void endTimer(String operation) {
    if (!_isEnabled) return;
    
    final timer = _timers[operation];
    if (timer != null) {
      timer.stop();
      _recordMetric(operation, timer.elapsedMilliseconds);
      _timers.remove(operation);
      TTSLogger.debug('结束计时: $operation (${timer.elapsedMilliseconds}ms)');
    }
  }
  
  /// 记录指标
  static void _recordMetric(String operation, int duration) {
    _metrics.putIfAbsent(operation, () => Queue<int>());
    _metrics[operation]!.add(duration);
    
    // 保持最近的记录数量
    if (_metrics[operation]!.length > _maxMetricHistory) {
      _metrics[operation]!.removeFirst();
    }
  }
  
  /// 增加计数器
  static void incrementCounter(String counter) {
    if (!_isEnabled) return;
    
    _counters[counter] = (_counters[counter] ?? 0) + 1;
    TTSLogger.debug('计数器增加: $counter = ${_counters[counter]}');
  }
  
  /// 记录事件
  static void recordEvent(String event, {Map<String, dynamic>? data}) {
    if (!_isEnabled) return;
    
    incrementCounter('event_$event');
    if (data != null) {
      TTSLogger.stats('事件记录: $event, 数据: $data');
    } else {
      TTSLogger.stats('事件记录: $event');
    }
  }
  
  /// 获取平均指标
  static Map<String, double> getAverageMetrics() {
    return _metrics.map((key, values) {
      if (values.isEmpty) return MapEntry(key, 0.0);
      final sum = values.reduce((a, b) => a + b);
      return MapEntry(key, sum / values.length);
    });
  }
  
  /// 获取最新指标
  static Map<String, int?> getLatestMetrics() {
    return _metrics.map((key, values) {
      return MapEntry(key, values.isEmpty ? null : values.last);
    });
  }
  
  /// 获取指标统计
  static Map<String, Map<String, dynamic>> getMetricStats() {
    return _metrics.map((key, values) {
      if (values.isEmpty) {
        return MapEntry(key, {
          'count': 0,
          'average': 0.0,
          'min': 0,
          'max': 0,
        });
      }
      
      final list = values.toList();
      list.sort();
      
      return MapEntry(key, {
        'count': list.length,
        'average': list.reduce((a, b) => a + b) / list.length,
        'min': list.first,
        'max': list.last,
        'median': list[list.length ~/ 2],
        'p95': list[(list.length * 0.95).floor()],
      });
    });
  }
  
  /// 获取计数器
  static Map<String, int> getCounters() {
    return Map.from(_counters);
  }
  
  /// 重置所有指标
  static void reset() {
    _timers.clear();
    _metrics.clear();
    _counters.clear();
    TTSLogger.config('性能监控指标已重置');
  }
  
  /// 生成性能报告
  static Map<String, dynamic> generateReport() {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'enabled': _isEnabled,
      'metrics': getMetricStats(),
      'counters': getCounters(),
      'active_timers': _timers.keys.toList(),
    };
    
    TTSLogger.stats('性能报告生成完成');
    return report;
  }
  
  /// 开始定期报告
  static void _startPeriodicReporting() {
    _stopPeriodicReporting();
    _reportTimer = Timer.periodic(_reportInterval, (timer) {
      _logPerformanceReport();
    });
  }
  
  /// 停止定期报告
  static void _stopPeriodicReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
  }
  
  /// 记录性能报告
  static void _logPerformanceReport() {
    final stats = getMetricStats();
    final counters = getCounters();
    
    TTSLogger.stats('=== 性能报告 ===');
    
    // 记录指标统计
    stats.forEach((operation, stat) {
      TTSLogger.stats(
        '$operation: 平均${stat['average']?.toStringAsFixed(1)}ms, '
        '最小${stat['min']}ms, 最大${stat['max']}ms, '
        '次数${stat['count']}'
      );
    });
    
    // 记录计数器
    if (counters.isNotEmpty) {
      TTSLogger.stats('计数器: ${counters.toString()}');
    }
    
    TTSLogger.stats('===============');
  }
  
  /// 检查性能异常
  static List<String> checkPerformanceIssues() {
    final issues = <String>[];
    final stats = getMetricStats();
    
    stats.forEach((operation, stat) {
      final average = stat['average'] as double;
      final max = stat['max'] as int;
      
      // 检查平均响应时间过长
      if (average > 2000) {
        issues.add('$operation 平均响应时间过长: ${average.toStringAsFixed(1)}ms');
      }
      
      // 检查最大响应时间过长
      if (max > 5000) {
        issues.add('$operation 最大响应时间过长: ${max}ms');
      }
    });
    
    return issues;
  }
  
  /// 获取性能健康状态
  static bool isPerformanceHealthy() {
    return checkPerformanceIssues().isEmpty;
  }
}