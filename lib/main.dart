import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/network/dio_client.dart';
import 'core/network/auth_manager.dart';
import 'core/storage/storage_service.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/app_router.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/providers/auth_state.dart';

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
    
    // 初始化认证管理器
    AuthManager.initialize();
    print('✅ 认证管理器初始化完成');
    
    // 初始化网络客户端，传递token过期处理回调
    DioClient.initialize(
      onTokenExpired: AuthManager.handleTokenExpired,
    );
    print('✅ 网络客户端初始化完成');
    
  } catch (e) {
    print('❌ 服务初始化失败: $e');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听认证状态变化
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && next.isUnauthenticated) {
        // 从已认证状态变为未认证状态，说明token过期
        if (next.errorMessage?.contains('登录已过期') == true) {
          // 跳转到登录页面
          final router = GoRouter.of(context);
          router.go(AppConstants.loginRoute);
          print('✅ [MyApp] 检测到登录过期，已跳转到登录页面');
        }
      }
    });

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
