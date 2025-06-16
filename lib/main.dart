import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/dio_client.dart';
import 'core/storage/storage_service.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化核心服务
  await _initializeServices();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

Future<void> _initializeServices() async {
  try {
    // 初始化本地存储
    await StorageService.initialize();
    print('✅ 本地存储初始化完成');
    
    // 初始化网络客户端
    DioClient.initialize();
    print('✅ 网络客户端初始化完成');
    
  } catch (e) {
    print('❌ 服务初始化失败: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A6FFF)),
        useMaterial3: true,
        fontFamily: 'SF Pro Text',
      ),
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
