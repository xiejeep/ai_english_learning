import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../providers/dify_apps_provider.dart';
import '../../../../shared/models/dify_app_model.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final difyAppsState = ref.watch(difyAppsProvider);
    
    // 监听认证状态变化，处理登录过期
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isUnauthenticated && next.errorMessage?.contains('登录已过期') == true) {
        // 显示登录过期提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('登录已过期，请重新登录'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // 跳转到登录页面
        context.go(AppConstants.loginRoute);
      }
    });
    
    // 监听Dify应用状态变化，显示错误信息
    ref.listen<DifyAppsState>(difyAppsProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: () {
                ref.read(difyAppsProvider.notifier).clearError();
                ref.read(difyAppsProvider.notifier).loadDifyApps();
              },
            ),
          ),
        );
      }
    });
    
    // 监听认证状态变化，在认证成功时加载Dify应用列表
    ref.listen<AuthState>(authProvider, (previous, next) {
      // 只在从未认证状态变为已认证状态时，且未加载过数据时才加载
      if (previous != null && 
          !previous.isAuthenticated && 
          next.isAuthenticated && 
          !difyAppsState.hasLoaded && 
          !difyAppsState.isLoading) {
        ref.read(difyAppsProvider.notifier).loadDifyApps();
      }
    });
    
    // 首次加载：如果用户已认证且未加载过数据，则加载应用列表
    // 使用addPostFrameCallback确保在build完成后执行，但只执行一次
    if (authState.isAuthenticated && !difyAppsState.hasLoaded && !difyAppsState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 再次检查状态，确保在回调执行时状态仍然满足条件
        final currentAuthState = ref.read(authProvider);
        final currentDifyAppsState = ref.read(difyAppsProvider);
        if (currentAuthState.isAuthenticated && 
            !currentDifyAppsState.hasLoaded && 
            !currentDifyAppsState.isLoading) {
          ref.read(difyAppsProvider.notifier).loadDifyApps();
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('趣TALK伙伴'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            tooltip: '个人中心',
            onPressed: () {
              context.push(AppConstants.profileRoute);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 欢迎卡片
              _buildWelcomeCard(context, authState),
              
              const SizedBox(height: 24),
              
              // 功能网格 - Dify应用列表
              Expanded(
                child: _buildDifyAppsGrid(context, ref, difyAppsState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.waving_hand,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '欢迎回来！',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            authState.user?.username ?? '用户',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '开始您的英语学习之旅吧！',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 构建Dify应用网格
  Widget _buildDifyAppsGrid(BuildContext context, WidgetRef ref, DifyAppsState difyAppsState) {
    if (difyAppsState.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              '正在加载应用列表...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (difyAppsState.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              difyAppsState.errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(difyAppsProvider.notifier).loadDifyApps();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (difyAppsState.apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.apps_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无可用应用',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请联系管理员添加应用',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(difyAppsProvider.notifier).refreshApps();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(difyAppsProvider.notifier).refreshApps();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemCount: difyAppsState.apps.length,
        itemBuilder: (context, index) {
          final app = difyAppsState.apps[index];
          return _buildDifyAppCard(context, app);
        },
      ),
    );
  }

  // 构建Dify应用卡片
  Widget _buildDifyAppCard(BuildContext context, DifyApp app) {
    // 根据应用类型选择图标和颜色
    IconData icon;
    Color color;
    
    switch (app.type?.toLowerCase() ?? '') {
      case 'chat':
      case 'chatbot':
        icon = Icons.chat_bubble_outline;
        color = Colors.blue;
        break;
      case 'agent':
        icon = Icons.smart_toy;
        color = Colors.purple;
        break;
      case 'workflow':
        icon = Icons.account_tree;
        color = Colors.orange;
        break;
      case 'completion':
        icon = Icons.edit_note;
        color = Colors.green;
        break;
      default:
        icon = Icons.apps;
        color = Colors.grey;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: app.enabled ? () {
          // 跳转到聊天页面，传递应用ID
          context.push('${AppConstants.chatRoute}?appId=${app.id}&appName=${Uri.encodeComponent(app.name)}');
        } : null,
        borderRadius: BorderRadius.circular(16),
        child: Opacity(
          opacity: app.enabled ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  app.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  app.description.isNotEmpty ? app.description : '暂无描述',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!app.enabled) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '暂不可用',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}