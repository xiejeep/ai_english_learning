// import 'dart:io';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:path_provider/path_provider.dart';
// import '../lib/core/services/tts_cache_service.dart';
// import '../lib/core/utils/tts_cache_diagnostics.dart';

// /// TTS缓存机制测试
// /// 用于验证缓存保存、查找和诊断功能
// void main() {
//   group('TTS缓存机制测试', () {
//     late TTSCacheService cacheService;
//     late TTSCacheDiagnostics diagnostics;
    
//     setUpAll(() async {
//       // 初始化缓存服务
//       cacheService = TTSCacheService();
//       await cacheService.initialize();
      
//       // 初始化诊断工具
//       diagnostics = TTSCacheDiagnostics();
//     });
    
//     test('缓存服务初始化测试', () async {
//       // 验证缓存服务是否正确初始化
//       expect(cacheService.isInitialized, true);
      
//       // 获取缓存统计
//       final stats = await cacheService.getCacheStats();
//       print('📊 缓存统计: ${stats['fileCount']} 个文件, ${stats['totalSizeMB'].toStringAsFixed(2)} MB');
      
//       // 验证缓存目录是否存在
//       final appDir = await getApplicationDocumentsDirectory();
//       final cacheDir = Directory('${appDir.path}/tts_cache');
//       expect(await cacheDir.exists(), true);
//     });
    
//     test('缓存保存和查找测试', () async {
//       const testMessage = 'Hello, this is a test message for TTS caching.';
      
//       // 创建一个测试音频文件
//       final tempDir = await getTemporaryDirectory();
//       final testAudioFile = File('${tempDir.path}/test_audio.mp3');
//       await testAudioFile.writeAsBytes([1, 2, 3, 4, 5]); // 模拟音频数据
      
//       // 测试缓存保存
//       print('💾 测试缓存保存...');
//       final cachedPath = await cacheService.cacheAudioFile(testMessage, testAudioFile.path);
//       expect(cachedPath.isNotEmpty, true);
//       print('✅ 音频已缓存: ${cachedPath.split('/').last}');
      
//       // 测试缓存查找
//       print('🔍 测试缓存查找...');
//       final hasCached = await cacheService.hasCachedAudio(testMessage);
//       expect(hasCached, true);
//       print('✅ 缓存查找成功');
      
//       // 测试获取缓存路径
//       final retrievedPath = await cacheService.getCachedAudioPath(testMessage);
//       expect(retrievedPath, isNotNull);
//       expect(retrievedPath, equals(cachedPath));
//       print('✅ 缓存路径获取成功: ${retrievedPath!.split('/').last}');
      
//       // 验证缓存文件是否存在
//       final cachedFile = File(cachedPath);
//       expect(await cachedFile.exists(), true);
//       print('✅ 缓存文件存在验证成功');
      
//       // 清理测试文件
//       await testAudioFile.delete();
//     });
    
//     test('缓存诊断测试', () async {
//       print('🔧 运行缓存诊断...');
//       final report = await diagnostics.runFullDiagnostics();
      
//       // 验证诊断报告
//       expect(report.isNotEmpty, true);
//       print('📋 诊断报告:');
//       print(report);
      
//       // 验证诊断报告包含关键信息
//       expect(report.contains('应用文档目录'), true);
//       expect(report.contains('缓存目录'), true);
//       expect(report.contains('缓存索引文件'), true);
//     });
    
//     test('缓存键一致性测试', () async {
//       const testMessage1 = 'Test message for consistency check';
//       const testMessage2 = 'Test message for consistency check'; // 相同内容
//       const testMessage3 = 'Different test message'; // 不同内容
      
//       // 创建测试音频文件
//       final tempDir = await getTemporaryDirectory();
//       final testAudioFile1 = File('${tempDir.path}/test_audio1.mp3');
//       final testAudioFile2 = File('${tempDir.path}/test_audio2.mp3');
      
//       await testAudioFile1.writeAsBytes([1, 2, 3, 4, 5]);
//       await testAudioFile2.writeAsBytes([6, 7, 8, 9, 10]);
      
//       // 缓存相同内容的消息
//       final cachedPath1 = await cacheService.cacheAudioFile(testMessage1, testAudioFile1.path);
//       final cachedPath2 = await cacheService.cacheAudioFile(testMessage2, testAudioFile2.path);
      
//       // 验证相同内容使用相同的缓存键
//       expect(cachedPath1, equals(cachedPath2));
//       print('✅ 相同内容使用相同缓存键验证成功');
      
//       // 缓存不同内容的消息
//       final cachedPath3 = await cacheService.cacheAudioFile(testMessage3, testAudioFile2.path);
      
//       // 验证不同内容使用不同的缓存键
//       expect(cachedPath1, isNot(equals(cachedPath3)));
//       print('✅ 不同内容使用不同缓存键验证成功');
      
//       // 清理测试文件
//       await testAudioFile1.delete();
//       await testAudioFile2.delete();
//     });
    
//     test('缓存统计准确性测试', () async {
//       // 获取初始统计
//       final initialStats = await cacheService.getCacheStats();
//       final initialCount = initialStats['fileCount'] as int;
      
//       // 添加一个新的缓存文件
//       const newTestMessage = 'New test message for stats verification';
//       final tempDir = await getTemporaryDirectory();
//       final newTestAudioFile = File('${tempDir.path}/new_test_audio.mp3');
//       await newTestAudioFile.writeAsBytes(List.generate(1024, (i) => i % 256)); // 1KB测试数据
      
//       await cacheService.cacheAudioFile(newTestMessage, newTestAudioFile.path);
      
//       // 获取更新后的统计
//       final updatedStats = await cacheService.getCacheStats();
//       final updatedCount = updatedStats['fileCount'] as int;
      
//       // 验证文件数量增加
//       expect(updatedCount, equals(initialCount + 1));
//       print('✅ 缓存统计准确性验证成功: $initialCount -> $updatedCount');
      
//       // 清理测试文件
//       await newTestAudioFile.delete();
//     });
//   });
// }