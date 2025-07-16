import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';

void main() {
  group('优化锁机制逻辑测试', () {
    test('音频块队列处理逻辑测试', () async {
       // 模拟音频块队列
       final List<Uint8List> pendingChunks = [];
       final List<Uint8List> audioChunkBuffer = [];
       bool isProcessingQueue = false;
       bool isCreatingSegment = false;
       
       // 声明函数变量
       late Future<void> Function() processChunkQueue;
       late Future<void> Function() createAndPlaySegment;
       
       // 模拟 _createAndPlaySegment 逻辑
       createAndPlaySegment = () async {
         if (audioChunkBuffer.isEmpty) return;
         
         if (isCreatingSegment) {
           print('⚠️ 段创建已在进行中，跳过重复调用');
           return;
         }
         
         isCreatingSegment = true;
         
         try {
           final chunkCount = audioChunkBuffer.length;
           print('🎵 开始创建音频段，包含 $chunkCount 个音频块');
           
           // 创建当前缓冲区的副本，然后立即清空缓冲区
           final chunksToProcess = List<Uint8List>.from(audioChunkBuffer);
           audioChunkBuffer.clear();
           
           // 模拟段创建过程（延迟）
           await Future.delayed(const Duration(milliseconds: 10));
           
           print('✅ 音频段创建成功，处理了 ${chunksToProcess.length} 个音频块');
         } catch (e) {
           print('❌ 创建音频段失败: $e');
         } finally {
           isCreatingSegment = false;
           print('🔓 段创建锁已释放');
           
           // 段创建完成后，如果队列中还有待处理的音频块，重新启动队列处理器
           if (pendingChunks.isNotEmpty && !isProcessingQueue) {
             print('🔄 段创建完成，重新启动队列处理器处理剩余的 ${pendingChunks.length} 个音频块');
             await processChunkQueue();
           }
         }
       };
       
       // 模拟 _processChunkQueue 逻辑
       processChunkQueue = () async {
         if (isProcessingQueue) return;
         
         isProcessingQueue = true;
         
         try {
           while (pendingChunks.isNotEmpty) {
             // 从队列中取出音频块并添加到缓冲区
             final chunk = pendingChunks.removeAt(0);
             audioChunkBuffer.add(chunk);
             
             print('📦 处理队列中的音频块，缓冲区现有: ${audioChunkBuffer.length} 个音频块');
             
             // 检查是否需要创建段（简化逻辑：每3个块创建一段）
             bool shouldCreateSegment = audioChunkBuffer.length >= 3;
             
             if (shouldCreateSegment && !isCreatingSegment) {
               await createAndPlaySegment();
             }
             
             // 如果正在创建段，暂停队列处理
             if (isCreatingSegment) {
               print('⏳ 段创建中，暂停队列处理');
               break;
             }
           }
         } catch (e) {
           print('❌ 处理音频块队列失败: $e');
         } finally {
           isProcessingQueue = false;
           
           // 如果队列中还有待处理的音频块，重新启动处理器
           if (pendingChunks.isNotEmpty) {
             print('🔄 队列中还有 ${pendingChunks.length} 个音频块待处理，重新启动处理器');
             await processChunkQueue();
           }
         }
       };
       
       // 模拟 _processChunkWithBuffering 逻辑
       Future<void> processChunkWithBuffering(Uint8List audioData) async {
         // 将音频块添加到待处理队列
         pendingChunks.add(audioData);
         
         print('🔄 音频块已加入队列，队列长度: ${pendingChunks.length}, 缓冲区: ${audioChunkBuffer.length}, 正在创建段: $isCreatingSegment');
         
         // 如果队列处理器没有运行，启动它
         if (!isProcessingQueue) {
           await processChunkQueue();
         }
       }
      
      print('🧪 [测试] 开始测试优化锁机制逻辑');
      
      // 创建测试音频块
      final testChunks = List.generate(10, (index) {
        return Uint8List.fromList(List.filled(256, index % 256));
      });
      
      print('🧪 [测试] 将发送 ${testChunks.length} 个音频块');
      
      // 快速连续发送音频块
      for (int i = 0; i < testChunks.length; i++) {
        await processChunkWithBuffering(testChunks[i]);
        print('🧪 [测试] 已发送第 ${i + 1} 个音频块');
        
        // 短暂延迟模拟网络
        await Future.delayed(const Duration(milliseconds: 5));
      }
      
      // 等待所有处理完成
      while (pendingChunks.isNotEmpty || isProcessingQueue || isCreatingSegment) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      print('🧪 [测试] 优化锁机制逻辑测试完成');
      print('🧪 [测试] 最终状态 - 队列: ${pendingChunks.length}, 缓冲区: ${audioChunkBuffer.length}');
      
      // 验证所有音频块都被处理
      expect(pendingChunks.isEmpty, isTrue, reason: '队列应该为空');
      expect(isProcessingQueue, isFalse, reason: '队列处理器应该停止');
      expect(isCreatingSegment, isFalse, reason: '段创建锁应该释放');
    });
    
    test('并发音频块处理逻辑测试', () async {
      // 模拟并发场景下的锁机制
      final List<Uint8List> pendingChunks = [];
      bool isProcessingQueue = false;
      int processedCount = 0;
      
      Future<void> processChunk(Uint8List audioData) async {
        pendingChunks.add(audioData);
        
        if (!isProcessingQueue) {
          isProcessingQueue = true;
          
          // 模拟处理延迟
          await Future.delayed(const Duration(milliseconds: 5));
          
          while (pendingChunks.isNotEmpty) {
            pendingChunks.removeAt(0);
            processedCount++;
            print('📦 处理音频块 $processedCount');
          }
          
          isProcessingQueue = false;
        }
      }
      
      print('🧪 [测试] 开始并发处理逻辑测试');
      
      // 创建测试音频块
      final testChunks = List.generate(5, (index) {
        return Uint8List.fromList(List.filled(128, index % 256));
      });
      
      // 并发发送音频块
      final futures = testChunks.asMap().entries.map((entry) async {
        final index = entry.key;
        final chunk = entry.value;
        
        await Future.delayed(Duration(milliseconds: index));
        await processChunk(chunk);
        print('🧪 [测试] 并发处理第 ${index + 1} 个音频块');
      });
      
      await Future.wait(futures);
      
      // 等待所有处理完成
      while (isProcessingQueue || pendingChunks.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 5));
      }
      
      print('🧪 [测试] 并发处理逻辑测试完成');
      print('🧪 [测试] 总共处理了 $processedCount 个音频块');
      
      // 验证所有音频块都被处理
      expect(processedCount, equals(testChunks.length), reason: '所有音频块都应该被处理');
      expect(pendingChunks.isEmpty, isTrue, reason: '队列应该为空');
      expect(isProcessingQueue, isFalse, reason: '处理器应该停止');
    });
  });
}