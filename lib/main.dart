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
import 'features/auth/presentation/providers/user_profile_provider.dart';
import 'features/auth/presentation/providers/theme_color_provider.dart';
import 'features/auth/presentation/pages/theme_settings_page.dart';
import 'features/home/presentation/providers/dify_apps_provider.dart';

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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  // 移除本地_state变量，直接用Provider
  @override
  Widget build(BuildContext context) {
    final themeColor = ref.watch(themeColorProvider).themeColor;
    // 监听认证状态变化
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && next.isUnauthenticated) {
        // 从已认证状态变为未认证状态，说明token过期
        if (next.errorMessage?.contains('登录已过期') == true) {
          // 清除 Dify 应用状态
          ref.read(difyAppsProvider.notifier).reset();
          
          // 跳转到登录页面
          final router = GoRouter.of(context);
          router.go(AppConstants.loginRoute);
          print('✅ [MyApp] 检测到登录过期，已跳转到登录页面');
        }
      }
      // 认证成功时预加载用户信息
      if (next.isAuthenticated) {
        print('[MyApp] 认证成功，预加载用户信息...');
        ref.read(userProfileProvider.notifier).loadUserProfile();
        
        // 如果之前有认证状态且从未认证变为已认证，说明是重新登录
        if (previous != null && !previous.isAuthenticated) {
          print('✅ [MyApp] 检测到重新登录成功，清除 Dify 应用状态');
          // 清除可能存在的错误状态，为重新加载做准备
          ref.read(difyAppsProvider.notifier).reset();
        }
      }
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: ThemeData(
        primaryColor: themeColor,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
        ),
        colorScheme: ColorScheme.light(
          primary: themeColor,
          secondary: themeColor,
          background: Colors.white,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onBackground: Colors.black87,
          onSurface: Colors.black87,
        ),
        fontFamily: 'SF Pro Text',
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
