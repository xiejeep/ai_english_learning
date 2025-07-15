// import 'dart:io';
// import 'package:path_provider/path_provider.dart';
// import '../lib/core/services/tts_cache_service.dart';
// import '../lib/core/utils/tts_cache_diagnostics.dart';

// /// 快速缓存诊断脚本
// /// 用于在应用运行时快速检查缓存状态和问题
// Future<void> main() async {
//   print('🔧 开始TTS缓存快速诊断...\n');
  
//   try {
//     // 1. 检查应用目录
//     print('📁 检查应用目录...');
//     final appDir = await getApplicationDocumentsDirectory();
//     print('   应用文档目录: ${appDir.path}');
//     print('   目录存在: ${await appDir.exists()}');
    
//     // 2. 检查缓存目录
//     print('\n📂 检查缓存目录...');
//     final cacheDir = Directory('${appDir.path}/tts_cache');
//     print('   缓存目录: ${cacheDir.path}');
//     print('   目录存在: ${await cacheDir.exists()}');
    
//     if (await cacheDir.exists()) {
//       final files = await cacheDir.list().toList();
//       print('   缓存文件数量: ${files.length}');
      
//       if (files.isNotEmpty) {
//         print('   缓存文件列表:');
//         for (final file in files) {
//           if (file is File) {
//             final stat = await file.stat();
//             print('     - ${file.path.split('/').last} (${stat.size} 字节)');
//           }
//         }
//       }
//     }
    
//     // 3. 检查缓存索引
//     print('\n📋 检查缓存索引...');
//     final indexFile = File('${cacheDir.path}/cache_index.json');
//     print('   索引文件: ${indexFile.path}');
//     print('   索引存在: ${await indexFile.exists()}');
    
//     if (await indexFile.exists()) {
//       final content = await indexFile.readAsString();
//       print('   索引内容长度: ${content.length} 字符');
//       if (content.length < 500) {
//         print('   索引内容预览: $content');
//       }
//     }
    
//     // 4. 初始化缓存服务
//     print('\n🔧 初始化缓存服务...');
//     final cacheService = TTSCacheService();
//     await cacheService.initialize();
//     print('   缓存服务初始化: ${cacheService.isInitialized ? '成功' : '失败'}');
    
//     // 5. 获取缓存统计
//     print('\n📊 获取缓存统计...');
//     final stats = await cacheService.getCacheStats();
//     print('   文件数量: ${stats['fileCount']}');
//     print('   总大小: ${stats['totalSizeMB'].toStringAsFixed(2)} MB');
//     print('   平均文件大小: ${stats['averageFileSizeMB'].toStringAsFixed(2)} MB');
    
//     // 6. 运行完整诊断
//     print('\n🔍 运行完整诊断...');
//     final diagnostics = TTSCacheDiagnostics();
//     final report = await diagnostics.runFullDiagnostics();
    
//     print('\n📋 诊断报告:');
//     print('=' * 50);
//     print(report);
//     print('=' * 50);
    
//     // 7. 测试缓存功能
//     print('\n🧪 测试缓存功能...');
//     const testMessage = 'Quick diagnostic test message';
    
//     // 检查是否已有缓存
//     final hasCached = await cacheService.hasCachedAudio(testMessage);
//     print('   测试消息缓存状态: ${hasCached ? '已缓存' : '未缓存'}');
    
//     if (hasCached) {
//       final cachedPath = await cacheService.getCachedAudioPath(testMessage);
//       if (cachedPath != null) {
//         final cachedFile = File(cachedPath);
//         print('   缓存文件存在: ${await cachedFile.exists()}');
//         if (await cachedFile.exists()) {
//           final stat = await cachedFile.stat();
//           print('   缓存文件大小: ${stat.size} 字节');
//         }
//       }
//     }
    
//     print('\n✅ 快速诊断完成！');
    
//   } catch (e, stackTrace) {
//     print('\n❌ 诊断过程中出现错误: $e');
//     print('📍 错误堆栈: $stackTrace');
//   }
// }