import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../constants/app_constants.dart';
import '../storage/storage_service.dart';

// 临时页面引用，后续会替换为实际页面
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 模拟启动加载时间
    await Future.delayed(const Duration(seconds: 2));
    
    // 检查用户登录状态
    final token = StorageService.getUserToken();
    
    if (mounted) {
      if (token != null) {
        // 已登录，跳转到主页
        context.go(AppConstants.homeRoute);
      } else {
        // 未登录，跳转到登录页
        context.go(AppConstants.loginRoute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4A6FFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 应用Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.psychology,
                size: 60,
                color: Color(0xFF4A6FFF),
              ),
            ),
            const SizedBox(height: 24),
            // 应用名称
            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            // 应用副标题
            const Text(
              'AI英语学习助手',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            // 加载指示器
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// 注意：现在使用实际的LoginPage组件（从auth模块导入）

// 临时的主页面
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI英语学习'),
        backgroundColor: const Color(0xFF4A6FFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              context.go(AppConstants.profileRoute);
            },
            icon: const Icon(Icons.person),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.home,
              size: 80,
              color: Color(0xFF4A6FFF),
            ),
            const SizedBox(height: 24),
            const Text(
              '主页面',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '即将开发...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                context.go(AppConstants.chatRoute);
              },
              child: const Text('开始英语对话'),
            ),
          ],
        ),
      ),
    );
  }
}

// 临时的个人中心页面
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        backgroundColor: const Color(0xFF4A6FFF),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person,
              size: 80,
              color: Color(0xFF4A6FFF),
            ),
            const SizedBox(height: 24),
            const Text(
              '个人中心',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '即将开发...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                // 显示确认退出登录的弹窗
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('退出登录'),
                      content: const Text('确定要退出登录吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('确定'),
                        ),
                      ],
                    );
                  },
                );
                
                // 用户确认退出登录
                if (shouldLogout == true) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.go(AppConstants.loginRoute);
                  }
                }
              },
              child: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }
}

// 临时的聊天页面
class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('英语对话'),
        backgroundColor: const Color(0xFF4A6FFF),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat,
              size: 80,
              color: Color(0xFF4A6FFF),
            ),
            SizedBox(height: 24),
            Text(
              '英语对话页面',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '即将开发...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 应用路由配置
class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.splashRoute,
    routes: [
      GoRoute(
        path: AppConstants.splashRoute,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.loginRoute,
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppConstants.registerRoute,
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: AppConstants.forgotPasswordRoute,
        name: 'forgot-password',
        builder: (context, state) {
          final email = state.uri.queryParameters['email'];
          return ForgotPasswordPage(initialEmail: email);
        },
      ),
      GoRoute(
        path: AppConstants.homeRoute,
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppConstants.chatRoute,
        name: 'chat',
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: AppConstants.profileRoute,
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppConstants.creditsRoute,
        name: 'credits',
        builder: (context, state) => const ProfilePage(), // 临时使用个人中心页
      ),
      GoRoute(
        path: AppConstants.checkinRoute,
        name: 'checkin',
        builder: (context, state) => const ProfilePage(), // 临时使用个人中心页
      ),
      GoRoute(
        path: AppConstants.settingsRoute,
        name: 'settings',
        builder: (context, state) => const ProfilePage(), // 临时使用个人中心页
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 24),
            const Text(
              '页面未找到',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '路径: ${state.matchedLocation}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.homeRoute),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    ),
  );
}